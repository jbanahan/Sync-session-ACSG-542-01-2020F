require 'open_chain/ftp_file_support'
require 'open_chain/entity_compare/comparator_helper'

module OpenChain; module CustomHandler; module Ascena; class AscenaBillingInvoiceFileGenerator
  include OpenChain::EntityCompare::ComparatorHelper
  include OpenChain::FtpFileSupport

  DUTY_SYNC ||= "ASCE_DUTY_BILLING"
  BROKERAGE_SYNC ||= "ASCE_BROKERAGE_BILLING"
  LEGACY_SYNC ||= "ASCE_BILLING"

  def generate_and_send entry_snapshot_json
    # Don't even bother trying to send anything if there are failing business rules...
    # There needs to be a rule in place to ensure that the Product Line (aka Brand) field
    # is populated with correct data...if it's not, then the org codes below won't match up.
    return unless mf(entry_snapshot_json, "ent_failed_business_rules").blank?

    # find all the broker invoices, then we can determine which one actually has been billed or not.
    broker_invoice_snapshots = json_child_entities entry_snapshot_json, "BrokerInvoice"

    return if broker_invoice_snapshots.length == 0

    entry = find_entity_object(entry_snapshot_json)
    return if entry.nil?

    # Lock the entry entirely because of how we have to update the broker references associated with the entry
    # and the way the kewill entry parser has to copy the broker invoice data across from an old broker invoice record
    # to a new one.
    Lock.with_lock_retry(entry) do
      unsent_invoices(entry, broker_invoice_snapshots).each_pair do |invoice_number, invoice_data|
        generate_and_send_invoice(entry_snapshot_json, invoice_data)
      end
    end

    nil
  end

  def po_organization_code code
    # Catherines = 7218
    # Dress Barn = 221
    # Justice = 151
    # Lane Bryant = 7220
    # Maurices = 218
    xrefs = {"CATHERINES" => "7218", "CA" => "7218", "DRESS BARN" => "221", "DB" => "221", "JUSTICE" => "151", "JST" => "151", "LANE BRYANT" => "7220", "LB" => "7220", "MAURICES" => "218", "MAU" => "218"}
    xrefs[code.to_s.strip.upcase]
  end

  private 
  
    def generate_and_send_invoice entry_snapshot, invoice_data
      broker_invoice_snapshot = invoice_data[:snapshot]
      invoice_number = mf(broker_invoice_snapshot, "bi_invoice_number")
      duty_file, brokerage_file = generate_data(entry_snapshot, broker_invoice_snapshot, invoice_data[:sync_types])

      broker_invoice = find_entity_object(broker_invoice_snapshot)
      return unless broker_invoice

      invoice_data[:sync_types].each do |sync_type|
        # Skip any types where the corresponding files are blank
        next if (sync_type == DUTY_SYNC && duty_file.blank?) || (sync_type == BROKERAGE_SYNC && brokerage_file.blank?)

        sr = broker_invoice.sync_records.where(trading_partner: sync_type).first_or_initialize
        
        if sync_type == DUTY_SYNC
          send_file(duty_file, sr, true)
        elsif sync_type == BROKERAGE_SYNC
          send_file(brokerage_file, sr)
        end

        sr.sent_at = Time.zone.now
        sr.confirmed_at = sr.sent_at + 1.minute
        sr.save!
      end
    end

    def send_file lines, sync_record, duty_file = false
      filename = "ASC_#{duty_file ? "DUTY" : "BROKER"}_INVOICE_AP_#{ActiveSupport::TimeZone["America/New_York"].now.strftime("%Y%m%d%H%M%S%L")}.dat"
      Tempfile.open([File.basename(filename, ".*"), File.extname(filename)]) do |f|
        Attachment.add_original_filename_method f, filename

        lines.each {|line| f << line.to_csv(col_sep: "|") }
        f.flush
        f.rewind
        ftp_sync_file f, sync_record, connect_vfitrack_net("to_ecs/_ascena_billing", filename)
      end
    end

    def generate_data entry_snapshot, broker_invoice_snapshot, sync_types
      duty_lines, non_duty_lines = split_duty_non_duty_lines(broker_invoice_snapshot)

      po_brand_org_codes = po_organization_ids entry_snapshot

      duty_file = []
      if sync_types.include?(DUTY_SYNC) && duty_lines.length > 0
        # We have to handle credit invoices with duty on them in a special way, so check if this is a credit invoices first
        invoice_total = duty_lines.map {|l| mf(l, "bi_line_charge_amount")}.compact.sum
        if invoice_total < 0
          duty_file = generate_duty_credit_invoice(broker_invoice_snapshot)
        end

        # At the very beginning of the change to process credit invoices in the above manner, we won't have any of the invoices
        # so we'll just continue to do them old (wrong) way if the file is blank
        if duty_file.blank?
          # Really there should only ever be a single duty line per file...but doesn't hurt to handle this like there could be more
          duty_file << invoice_header_fields(broker_invoice_snapshot, duty_lines, duty_invoice: true)
          line_number = 1
          duty_lines.each do |line|
            charge_lines = invoice_line_duty_fields(entry_snapshot, broker_invoice_snapshot, line_number, po_brand_org_codes)
            duty_file.push *charge_lines
            line_number += charge_lines.length
          end
        end
      end

      non_duty_file = []
      if sync_types.include?(BROKERAGE_SYNC) && non_duty_lines.length > 0
        non_duty_file << invoice_header_fields(broker_invoice_snapshot, non_duty_lines, duty_invoice: false)
        line_number = 1
        non_duty_lines.each do |line|
          charge_lines = invoice_line_brokerage_fields(broker_invoice_snapshot, line, line_number, po_brand_org_codes)
          non_duty_file.push *charge_lines
          line_number += charge_lines.length
        end
      end

      [duty_file, non_duty_file]
    end

    def invoice_header_fields broker_invoice_snapshot, brokerage_lines, duty_invoice: false
      fields = []
      invoice_total = brokerage_lines.map {|l| mf(l, "bi_line_charge_amount")}.compact.sum
      fields[0] = "H"
      fields[1] = mf(broker_invoice_snapshot, "bi_invoice_number")
      fields[2] = invoice_total > 0 ? "STANDARD" : "CREDIT"
      fields[3] = mf(broker_invoice_snapshot, "bi_invoice_date").try(:strftime, "%m/%d/%Y")
      # 00151 = Ascena's US Customs Vendor Code
      # 77519 = Ascena's Vandegrift Vendor Code
      fields[4] = duty_invoice ? "00151" : "77519"
      fields[5] = invoice_total
      fields[6] = "USD"
      fields[7] = "For Customs Entry # #{mf(broker_invoice_snapshot, "bi_entry_num")}"

      fields
    end

    def invoice_line_brokerage_fields broker_invoice_snapshot, broker_invoice_line, next_line_number, po_org_codes
      # Every brokerage charge needs to be "prorated" across all the PO #'s on the entry.
      # This is done solely based the # of PO's on the entry...ergo, each billing line (b) exploads into 
      # b * (# PO numbers) line.
      po_numbers = mf(broker_invoice_snapshot, "bi_ent_po_numbers").to_s.split(/\n\s*/)
      # If there were no PO numbers, add a blank so we make sure we bill the line
      po_numbers << "" if po_numbers.length == 0

      charge_amount = mf(broker_invoice_line, "bi_line_charge_amount")
      invoice_number = mf(broker_invoice_snapshot, "bi_invoice_number")
      charge_description = mf(broker_invoice_line, "bi_line_charge_description")

      prorations = {}
      if po_numbers.length == 1
        prorations[po_numbers.first] = charge_amount
      else
        # Don't round this value, we'll truncate the actual calculated values.
        proration_factor = (charge_amount / po_numbers.length)

        # If there are more PO's than charge dollars (super tiny corner case), then we don't 
        # have to turn the factor into a fraction...tne proration factor is the actual charge amount
        # already. - > $3 / 4 PO's -> .75 per PO. $20 / 40 PO's -> .50 per PO
        fractional = po_numbers.length > charge_amount
        proration_factor = proration_factor / 100 unless fractional

        
        total_remaining = BigDecimal(charge_amount)

        po_numbers.each do |po|
          prorated_value = (fractional ? proration_factor : (charge_amount * proration_factor)).round(2, BigDecimal::ROUND_DOWN)
          prorations[po] = prorated_value
          total_remaining -= prorated_value
        end

        # Now distribute the remaining amounts after the rounded proration across the po's one cent at a time.
        begin
          one_cent = BigDecimal("0.01")
          po_numbers.each do |po|
            total_remaining -= one_cent
            prorations[po] += one_cent

            break if total_remaining == 0
          end
        end while total_remaining > 0
      end

      lines = []
      next_line_number -= 1 # Just so we can always use +=1 in the loop
      prorations.each_pair do |po, amount|
        line = []
        line[0] = "L"
        line[1] = invoice_number
        line[2] = (next_line_number += 1)
        line[3] = "77519"
        line[4] = amount
        line[5] = charge_description
        line[6] = po
        line[7] = po_org_codes[po]

        lines << line
      end

      lines
    end

    def invoice_line_duty_fields entry_snapshot, broker_invoice_snapshot, next_line_number, po_org_codes
      po_duty_amounts = calculate_duty_amounts(entry_snapshot)

      invoice_number = mf(broker_invoice_snapshot, "bi_invoice_number")

      lines = []
      next_line_number -= 1 # Just so we can always use +=1 in the loop
      po_duty_amounts.each_pair do |po, amount|
        line = []
        line[0] = "L"
        line[1] = invoice_number
        line[2] = (next_line_number += 1)
        line[3] = "00151" # Ascena's US Customs Vendor Code
        line[4] = amount
        line[5] = "Duty"
        line[6] = po
        line[7] = po_org_codes[po]

        lines << line
      end

      lines
    end

    def split_duty_non_duty_lines broker_invoice_snapshot
      invoice_lines = json_child_entities(broker_invoice_snapshot, "BrokerInvoiceLine")

      # split into duty vs. non-duty lines...we need to send duty lines in a separate file with a different 
      # vendor id for them
      duty_lines, non_duty_lines = invoice_lines.partition {|l| ["0001", "0099"].include?(mf(l, "bi_line_charge_code")) }

      # reject any lines marked as duty paid direct (code 0099) - they don't need to be billed (since they're not an actual charge
      # rather a reflection on the invoice that the customer is repsonsible for duty payments).  Every time a 99 charge comes
      # across there should also be a Duty (0001) charge on the invoice as well.
      duty_lines = duty_lines.reject {|l| mf(l, "bi_line_charge_code").to_s.upcase == "0099"}

      [duty_lines, non_duty_lines]
    end

    # This is a funky situation...we need to credit the exact duty amounts back to ascena HOWEVER since
    # the duty data is generated directly from the entry commercial invoice lines it's very possible that
    # the duty amounts on those lines have been changed.  This is a common scenario when the duty is billed
    # and then tariff numbers are ammended after the fact, which changes the dutiable amounts.
    #
    # In this situation, what we're going to do is retrieve the original file from the ftp session linked to the
    # sync record on the initial duty billing invoice.  Then we'll just flip the sign on all the duty lines.
    def generate_duty_credit_invoice broker_invoice_snapshot
      duty_lines, * = split_duty_non_duty_lines(broker_invoice_snapshot)
      duty_amount = mf(duty_lines.first, "bi_line_charge_amount") * -1

      # Find the original broker invoice that had the billed duty amount we're looking for.
      broker_reference = mf(broker_invoice_snapshot, "bi_brok_ref")

      original_invoices = BrokerInvoice.joins(:entry, :broker_invoice_lines).where(broker_invoice_lines: {charge_code: '0001', charge_amount: duty_amount}).where(entries: {broker_reference: broker_reference, customer_number: mf(broker_invoice_snapshot, "bi_ent_cust_num")}).order("invoice_date DESC, id DESC").all
      sync_record = nil
      original_invoices.each do |invoice|
        sync_record = invoice.sync_records.where(trading_partner: DUTY_SYNC).where("ftp_session_id IS NOT NULL").first
        break if sync_record
      end
      
      return [] unless sync_record

      lines = nil
      sync_record.ftp_session.attachment.download_to_tempfile do |tf|
        lines = CSV.parse tf.read, col_sep: "|"
      end

      # Now all we have to do is invert the amounts from the original file and then return those
      invoice_number = mf(broker_invoice_snapshot, "bi_invoice_number")
      lines.each do |row|
        case row[0]
        when "H"
          row[1] = invoice_number
          row[2] = "CREDIT"
          row[3] = mf(broker_invoice_snapshot, "bi_invoice_date").try(:strftime, "%m/%d/%Y")
          row[5] = (BigDecimal(row[5]) * -1)
        when "L"
          row[1] = invoice_number
          row[4] = (BigDecimal(row[4]) * -1)
        end
      end

      lines
    end

    def unsent_invoices entry, broker_invoice_snapshots
      invoices = {}
      broker_invoice_snapshots.each do |bi|
        invoice_number = mf(bi, "bi_invoice_number")
        broker_invoice = entry.broker_invoices.find {|inv| inv.invoice_number == invoice_number}

        # It's possible the invoice won't be found because it may have been updated in the intervening time from Kewill
        next if broker_invoice.nil? || broker_invoice.sync_records.find {|s| s.trading_partner == LEGACY_SYNC }.present?

        invoice_data = {snapshot: bi, sync_types: []}

        [DUTY_SYNC, BROKERAGE_SYNC].each do |sync|
          sr = broker_invoice.sync_records.find {|s| s.trading_partner == sync }
          invoice_data[:sync_types] << sync if sr.nil? || sr.sent_at.nil?
        end

        invoices[broker_invoice.invoice_number] = invoice_data if invoice_data[:sync_types].length > 0
      end

      invoices
    end

    def calculate_duty_amounts entry_snapshot
      invoice_lines = json_child_entities entry_snapshot, "CommercialInvoice", "CommercialInvoiceLine"

      po_duty = Hash.new do |h, k|
        h[k] = BigDecimal("0")
      end

      invoice_lines.each do |line|
        po_number = mf(line, "cil_po_number")
        po_duty[po_number] += BigDecimal(mf(line, "cil_total_duty_plus_fees"))
      end

      po_duty
    end

    def po_organization_ids entry_snapshot
      po_numbers = {}
      invoice_lines = json_child_entities entry_snapshot, "CommercialInvoice", "CommercialInvoiceLine"

      
      invoice_lines.each do |line|
        po_number = mf(line, "cil_po_number")
        brand_code = po_organization_code(mf(line, "cil_product_line"))

        po_numbers[po_number] = brand_code unless po_number.blank? || brand_code.blank?
      end

      po_numbers
    end

end; end; end; end