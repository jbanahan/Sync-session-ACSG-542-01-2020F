require 'open_chain/ftp_file_support'
require 'open_chain/entity_compare/comparator_helper'
require 'fuzzy_match'

module OpenChain; module CustomHandler; module Ascena; class AscenaBillingInvoiceFileGenerator
  include OpenChain::EntityCompare::ComparatorHelper
  include OpenChain::FtpFileSupport

  DUTY_SYNC ||= "ASCE_DUTY_BILLING"
  BROKERAGE_SYNC ||= "ASCE_BROKERAGE_BILLING"
  DUTY_CORRECTION_SYNC ||= "ASCE_DUTY_CORRECTION_BILLING"
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
        generate_and_send_invoice(entry_snapshot_json, invoice_data, entry)
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
  
    def generate_and_send_invoice entry_snapshot, invoice_data, entry
      broker_invoice_snapshot = invoice_data[:snapshot]
      invoice_number = mf(broker_invoice_snapshot, "bi_invoice_number")
      broker_invoice = entry.broker_invoices.find {|i| i.invoice_number == invoice_number }
      return unless broker_invoice

      po_brand_org_codes = po_organization_ids entry_snapshot
      invoice_data[:invoice_lines].each_pair do |sync_type, invoice_lines|
        # Skip any types where the corresponding files will be blank
        next if invoice_lines.blank?

        file_data = generate_invoice_file_data(entry_snapshot, broker_invoice_snapshot, po_brand_org_codes, sync_type, invoice_lines)
        sr = broker_invoice.sync_records.where(trading_partner: sync_type).first_or_initialize
        prefix = entry_snapshot["entity"]["model_fields"]["ent_cust_num"] == "MAUR" ? "MAUR" : "ASC"
        send_file(file_data, invoice_number, sr, prefix, duty_file: (sync_type == DUTY_CORRECTION_SYNC || sync_type == DUTY_SYNC))
        sr.sent_at = Time.zone.now
        sr.confirmed_at = sr.sent_at + 1.minute
        sr.save!
      end
    end

    def send_file lines, invoice_number, sync_record, prefix, duty_file: false
      filename = "#{prefix}_#{duty_file ? "DUTY" : "BROKER"}_INVOICE_AP_#{invoice_number}_#{ActiveSupport::TimeZone["America/New_York"].now.strftime("%Y%m%d%H%M%S%L")}.dat"
      Tempfile.open([File.basename(filename, ".*"), File.extname(filename)]) do |f|
        Attachment.add_original_filename_method f, filename

        lines.each {|line| f << line.to_csv(col_sep: "|") }
        f.flush
        f.rewind
        ftp_sync_file f, sync_record, connect_vfitrack_net("to_ecs/_ascena_billing", filename)
      end
    end

    def generate_invoice_file_data entry_snapshot, broker_invoice_snapshot, po_brand_org_codes, sync_type, invoice_lines
      file_data = []
      if sync_type == DUTY_SYNC
        file_data = generate_duty_invoice_file(entry_snapshot, broker_invoice_snapshot, po_brand_org_codes, invoice_lines)
      elsif sync_type == BROKERAGE_SYNC
        file_data = generate_broker_invoice_file(entry_snapshot, broker_invoice_snapshot, po_brand_org_codes, invoice_lines)
      elsif sync_type = DUTY_CORRECTION_SYNC
        file_data = generate_duty_correction_file(entry_snapshot, broker_invoice_snapshot, po_brand_org_codes, invoice_lines)
      end

      file_data
    end

    def generate_duty_invoice_file entry_snapshot, broker_invoice_snapshot, po_brand_org_codes, invoice_lines
      file_data = []
      # We have to handle credit invoices with duty on them in a special way, so check if this is a credit invoices first
      invoice_total = invoice_lines.map {|l| mf(l, "bi_line_charge_amount")}.compact.sum
      if invoice_total < 0
        file_data = generate_duty_credit_invoice(broker_invoice_snapshot)
      end

      # At the very beginning of the change to process credit invoices in the above manner, we won't have any of the invoices
      # so we'll just continue to do them old (wrong) way if the file is blank
      if file_data.blank?
        # Really there should only ever be a single duty line per file...but doesn't hurt to handle this like there could be more
        file_data << invoice_header_fields(broker_invoice_snapshot, invoice_lines, duty_invoice: true)
        line_number = 1
        invoice_lines.each do |line|
          charge_lines = invoice_line_duty_fields(entry_snapshot, broker_invoice_snapshot, line_number, po_brand_org_codes)
          file_data.push *charge_lines
          line_number += charge_lines.length
        end
      end

      file_data
    end

    def generate_broker_invoice_file(entry_snapshot, broker_invoice_snapshot, po_brand_org_codes, invoice_lines)
      file_data = []

      file_data << invoice_header_fields(broker_invoice_snapshot, invoice_lines, duty_invoice: false)
      line_number = 1
      invoice_lines.each do |line|
        charge_lines = invoice_line_brokerage_fields(broker_invoice_snapshot, line, line_number, po_brand_org_codes)
        file_data.push *charge_lines
        line_number += charge_lines.length
      end

      file_data
    end

    def generate_duty_correction_file(entry_snapshot, broker_invoice_snapshot, po_brand_org_codes, invoice_lines)
      file_data = []

      # We outlay the duty for Ascena in this scenario so we should be listed as the vendor, not US Customs
      file_data << invoice_header_fields(broker_invoice_snapshot, invoice_lines, duty_invoice: false)
      line_number = 1

      invoice_lines.each do |line|
        lines = invoice_line_duty_correction_fields(broker_invoice_snapshot, line, line_number, po_brand_org_codes)
        file_data.push *lines
        line_number += lines.length
      end

      file_data
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

    def invoice_line_duty_correction_fields broker_invoice_snapshot, broker_invoice_line, next_line_number, po_org_codes
      amount = mf(broker_invoice_line, "bi_line_charge_amount")
      # Whoever is billing this is supposed to be keying the PO Number that the corrected duty amount belongs to on the charge description
      # This is really the only way we can actually determine the PO that is having it's duty amounts adjusted.
      # Also, do some fuzzy matching because the likelihood that the PO number is miskeyed at some point is high and we 
      # just want to get an actual PO number on here
      po = best_match_po_number(mf(broker_invoice_line, "bi_line_charge_description"), po_org_codes)

      invoice_number = mf(broker_invoice_snapshot, "bi_invoice_number")

      line = []
      line[0] = "L"
      line[1] = invoice_number
      line[2] = next_line_number
      line[3] = "77519" # Ascena's Vandegrift Vendor Code
      line[4] = amount
      line[5] = "Duty"
      line[6] = po
      line[7] = po_org_codes[po]

      [line]
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
        proration_factor = (charge_amount / po_numbers.length).abs
        # It's easier to handle prorations with the calculations all being positive values..then just flipping the sign
        # after everything has been calculated out at the end (rather than having to figure out if we need to add/subtract for
        # each calculation based on the charge being a debit/credit)
        negative_charge = charge_amount < 0
        
        total_remaining = BigDecimal(charge_amount).abs

        po_numbers.each do |po|
          prorated_value = proration_factor.round(2, BigDecimal::ROUND_DOWN)
          prorations[po] = prorated_value
          total_remaining -= prorated_value
        end

        # Now distribute the remaining amounts after the rounded proration across the po's one cent at a time.
        while total_remaining > 0
          one_cent = BigDecimal("0.01")
          po_numbers.each do |po|
            total_remaining -= one_cent
            prorations[po] += one_cent

            break if total_remaining == 0
          end
        end

        if negative_charge
          prorations.each_pair do |k, v|
            prorations[k] = v * -1
          end
        end
        
        if !valid_charge_amount?(prorations, charge_amount)
          raise "Invalid Ascena proration calculation for Invoice # '#{invoice_number}'. Should have billed $#{charge_amount}, actually billed $#{prorations.values.sum}."
        end
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

    # Broken out solely so the method can be override / mocked for test casing
    def valid_charge_amount? prorations, charge_amount
      # This is bad...it means our proration calculation algorithm is straight up wrong and we over/under billed.
      # This shouldn't happen, but if it does we want to catch it before it goes out to the customer.
      prorations.values.sum == charge_amount
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

    def split_broker_invoice_lines broker_invoice_snapshot
      # split the lines into the distinct type of file to generate
      duty_lines = []
      non_duty_lines = []
      post_summary_duty_adjustment_lines = []

      json_child_entities(broker_invoice_snapshot, "BrokerInvoiceLine") do |invoice_line|
        charge_code = mf(invoice_line, "bi_line_charge_code")
        case charge_code
        when duty_codes
          duty_lines << invoice_line
        when skip_codes
          #skip these lines
        when post_summary_duty_codes
          # This is a special charge code to indicate a duty adjustment owed on a file that's had a post summary correction issued.
          # We have to handle this specially because what's billed is not the full duty amount owed, rather the difference
          # owed between what was paid and what is now owed after the correction
          post_summary_duty_adjustment_lines << invoice_line
        else
          non_duty_lines << invoice_line
        end
      end

      {DUTY_SYNC => duty_lines, BROKERAGE_SYNC => non_duty_lines, DUTY_CORRECTION_SYNC => post_summary_duty_adjustment_lines}
    end

    def duty_codes
      @duty_charge_codes ||= Set.new ["0001"]
    end

    def skip_codes
      # skip any lines marked as duty paid direct (code 0099) - they don't need to be billed (since they're not an actual charge
      # rather a reflection on the invoice that the customer is repsonsible for duty payments).  Every time a 99 charge comes
      # across there should also be a Duty (0001) charge on the invoice as well.
      @skip_charge_codes ||= Set.new ["0099"]
    end

    def post_summary_duty_codes
      @post_summary_duty_charge_codes ||= Set.new ["0255"]
    end

    # This is a funky situation...we need to credit the exact duty amounts back to ascena HOWEVER since
    # the duty data is generated directly from the entry commercial invoice lines it's very possible that
    # the duty amounts on those lines have been changed.  This is a common scenario when the duty is billed
    # and then tariff numbers are ammended after the fact, which changes the dutiable amounts.
    #
    # In this situation, what we're going to do is retrieve the original file from the ftp session linked to the
    # sync record on the initial duty billing invoice.  Then we'll just flip the sign on all the duty lines.
    def generate_duty_credit_invoice broker_invoice_snapshot
      duty_lines = split_broker_invoice_lines(broker_invoice_snapshot)[DUTY_SYNC]
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

        invoice_data = {snapshot: bi, invoice_lines: {DUTY_SYNC => [], BROKERAGE_SYNC => [], DUTY_CORRECTION_SYNC => []}}

        split_lines = split_broker_invoice_lines(bi)

        data_present = false
        [DUTY_SYNC, BROKERAGE_SYNC, DUTY_CORRECTION_SYNC].each do |sync|
          if split_lines[sync].length > 0
            sr = broker_invoice.sync_records.find {|s| s.trading_partner == sync }
            if sr.nil? || sr.sent_at.nil?
              invoice_data[:invoice_lines][sync] = split_lines[sync] 
              data_present = true
            end
          end
        end

        invoices[broker_invoice.invoice_number] = invoice_data if data_present
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

    def best_match_po_number po_number, po_org_codes
      code = po_org_codes[po_number]
      return po_number unless code.nil?

      # This will help if ops typos a PO number...it gets us close enough to an actual PO number on the entry
      fz = FuzzyMatch.new(po_org_codes.keys.to_a)
      actual_po_number = fz.find(po_number)

      actual_po_number.blank? ? nil : actual_po_number
    end

end; end; end; end
