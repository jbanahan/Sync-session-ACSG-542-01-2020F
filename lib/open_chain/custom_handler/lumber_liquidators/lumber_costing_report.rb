require 'digest'
require 'open_chain/polling_job'
require 'open_chain/ftp_file_support'
require 'open_chain/api/order_api_client'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberCostingReport
  include OpenChain::PollingJob
  include OpenChain::FtpFileSupport
  include ActionView::Helpers::NumberHelper

  def self.run_schedulable
    self.new.run
  end

  def initialize opts = {}
    @env = opts[:env].presence || :production
    @api_client = opts[:api_client]
  end

  def ftp_credentials
    connect_vfitrack_net 'to_ecs/lumber_costing_report'
  end

  def run start_time: Time.zone.now
    # We want to find anything updated since the last time this job ran to completion (at this point, the job is supposed
    # to be scheduled nightly at midnight)
    ids = find_entry_ids start_time

    ids.each do |id|
      generate_and_send_entry_data id
    end
  end

  def generate_and_send_entry_data id
    entry, data = generate_entry_data(id)
    if !data.blank?
      sync_record = entry.sync_records.where(trading_partner: "LL_COST_REPORT").first_or_initialize

      # There should never be a sync record already existing, since we should NEVER send data for invoices that we've already sent data for
      return if sync_record.persisted?

      Tempfile.open(["Cost_", ".txt"]) do |temp|
        Attachment.add_original_filename_method temp, "Cost_#{entry.broker_reference}_#{ActiveSupport::TimeZone["America/New_York"].now.strftime("%Y-%m-%d")}.txt"
        
        data.each do |row|
          temp << row.to_csv(col_sep: "|")
        end
        temp.flush
        temp.rewind

        SyncRecord.transaction do
          ftp_file temp
          sync_record.sent_at = Time.zone.now
          sync_record.confirmed_at = Time.zone.now + 1.minute
          sync_record.save!
        end
        
      end
    end
  rescue => e
    raise e if Rails.env.test?
    e.log_me
  end

  def find_entry_ids start_time
    # Data should be sent ONLY ONCE and not sent until Arrival Date - 3 days.
    v = Entry.select("DISTINCT entries.id").
          # We have to have broker invoices before we send this data
          joins(:broker_invoices).
          joins("LEFT OUTER JOIN sync_records sync ON sync.syncable_id = entries.id AND sync.syncable_type = 'Entry' and sync.trading_partner = 'LL_COST_REPORT'").
          where(source_system: "Alliance", customer_number: "LUMBER").
          # Lumber wants these when Arrival Date is 3 days out (.ie Arrival Date minus 3)
          where("entries.arrival_date IS NOT NULL AND date_sub(date(entries.arrival_date), interval 3 day) <= date(?)", start_time).
          # If we haven't sent the file already we should send it OR if someone marks the sync record as needing to be resent (.ie sent_at is null)
          # This happens in cases where the file is audited and something is wrong in it.  The person auditing the file needs to correct the file / invoice
          # data and mark the sync record for resend.  Then the automated process will pick up the file again and regenerate it with the fixed data.
          where("sync.id IS NULL OR sync.sent_at IS NULL")
    v.pluck :id
  end

  def generate_entry_data entry_id 
    entry = Entry.where(id: entry_id).includes(commercial_invoices: [commercial_invoice_lines: [:commercial_invoice_tariffs]], broker_invoices: [:broker_invoice_lines]).first

    entry_data = []
    values = []

    # Don't continue if any business rules have failed (these easier to do here than in the query since there can be multiple validation templates / rule results
    # associated with the same entry
    if entry && !entry.business_validation_results.any?(&:failed?)
      
      total_entered_value = entry.entered_value
      charge_totals = calculate_charge_totals(entry)
      charge_buckets = charge_totals.deep_dup

      entry.commercial_invoices.each do |inv|
        inv.commercial_invoice_lines.each do |line|

          line_number = find_po_line(line.po_number, line.part_number)

          # There is supposed to be business rules preventing the entry of any po / parts that were not on existing orders
          # That's why we raise an error if the line number isn't found, the validation rule should have already marked this 
          # and the code should not have made it to this execution point - since we don't process entries with failed business rules (see above)
          raise "Unable to find Lumber PO Line Number for PO # '#{line.po_number}' and Part '#{line.part_number}'." if line_number.nil?


          line_values = line_charge_values(line, total_entered_value, charge_totals, charge_buckets)

          line_values[:entry_number] = entry.entry_number
          line_values[:bol] = entry.master_bills_of_lading
          line_values[:container] = line.container.try(:container_number)
          line_values[:po] = line.po_number
          line_values[:line_number] = line_number
          line_values[:part] = line.part_number
          line_values[:quantity] = (line.quantity.try(:nonzero?) ? line.quantity : "")
          line_values[:vendor_code] = "802542"
          line_values[:value] = line.value
          line_values[:other] = ""
          line_values[:currency] = "USD"
          values << line_values
        end
      end

      # For every proration cent left over in the buckets, spread out the value over all the line items tenth of a cent by tenth of a cent
      # (since they want the values down to 3 decimal places)
      # There's probably some formulaic way to do this rather than iteratively, but we're not going to be dealing w/ vast
      # numbers of lines, so this should work just fine.
      if values.length > 0
        charge_buckets.each_pair do |k, v|
          next unless v > 0
          val = v

          cent = BigDecimal("0.001")
          begin
            values.each do |line|
              next unless line[:entered_value].nonzero?

              # Skip the line if the entered value on the line is zero...since a zero entered value means the line has
              # no value to input into the total proration, it should not receive any back from the leftover.
              line[k] += cent
              val -= cent
              break if val <= 0
            end
          end while val > 0
        end
      end
      

      values.each do |line|
        row = [
              line[:entry_number], line[:bol], line[:container], line[:po], line[:line_number], line[:part], line[:quantity], line[:vendor_code], line[:value],
              line[:ocean_rate], line[:duty], line[:add], line[:cvd], line[:brokerage], line[:acessorial], line[:isc_management], line[:isf], line[:blp_handling], 
              line[:blp], line[:pier_pass], line[:hmf], line[:mpf], line[:inland_freight], line[:courier], line[:oga], line[:clean_truck], line[:other], line[:currency]
            ]

        # Since we're aping an existing feed, which doesn't send zeros, for some reason, remove them here too
        row = row.map do |v| 
          if v.is_a?(Numeric)
            if v == 0
              nil
            else
              number_with_precision(v, precision: 3)
            end
          else
            v = v.to_s
            v.blank? ? nil : v
          end
        end

        entry_data << row

      end

    end

    [entry, entry_data]
  end

  def line_charge_values line, total_entered_value, charge_totals, charge_buckets
    # Don't round this value, we'll round the end amount to 3 decimals
    proration_percentage = total_entered_value.try(:nonzero?) ? (line.total_entered_value / total_entered_value) : 0

    c = {}
    c[:entered_value] = (line.total_entered_value.presence || BigDecimal("0"))
    c[:duty] = line.total_duty
    c[:add] = line.add_duty_amount
    c[:cvd] = line.cvd_duty_amount
    c[:hmf] = line.hmf
    c[:mpf] = line.prorated_mpf

    # Figure the "ideal" proration value, we'll then compare to what's technically left over from the actual charge buckets
    prorated_values.each do |k|
      ideal_proration = (charge_totals[k] * proration_percentage).round(3, BigDecimal::ROUND_HALF_UP)

      # If we go negative, it means the proration amount is too big to alot the full localized amount (in general, this should basically just be a few pennies
      # that we'll short the final line on)
      value = nil
      if (charge_buckets[k] - ideal_proration) < 0
        value = charge_buckets[k]
      else
        value = ideal_proration
      end

      c[k] = value
      charge_buckets[k] -= value
    end

    c
  end

  def calculate_charge_totals entry
    totals = Hash.new do |h, k|
      h[k] = BigDecimal("0")
    end

    entry.broker_invoices.each do |inv|
      calculate_charge_totals_per_invoice inv, totals
    end

    totals
  end

  def calculate_charge_totals_per_invoice invoice, totals = nil
    if totals.nil?
      totals = Hash.new do |h, k|
        h[k] = BigDecimal("0")
      end
    end

    xref = charge_xref
    invoice.broker_invoice_lines.each do |line|
      rate_type = xref[line.charge_code]
      if rate_type && line.charge_amount
        totals[rate_type] += line.charge_amount
      end
    end

    totals
  end

  def charge_xref
    {
      '0004' => :ocean_rate,
      '0007' => :brokerage,
      '0176' => :acessorial,
      '0050' => :acessorial,
      '0142' => :acessorial,
      '0235' => :isc_management,
      '0191' => :isf,
      '0189' => :pier_pass,
      '0720' => :pier_pass,
      '0739' => :pier_pass,
      '0212' => :inland_freight,
      '0016' => :courier,
      '0031' => :oga,
      '0125' => :oga,
      '0026' => :oga,
      '0193' => :clean_truck,
      '0196' => :clean_truck
    }
  end

  def prorated_values 
    [:ocean_rate, :brokerage, :acessorial, :isc_management, :isf, :blp_handling, :blp, :pier_pass, :inland_freight, :courier, :oga, :clean_truck]
  end

  def find_po_line po, part
    # There should be a business rule preventing this class from even running if there is no PO/Part connection.
    # Still, be on guard here....
    part = normalize_part_number(part)
    @order_cache ||= {}
    order = @order_cache[po]
    if order.nil?
      order = order_api_client.find_by_order_number po, [:ord_ord_num, :ordln_line_number, :ordln_puid]
      if order['order'].nil? || Array.wrap(order['order']['order_lines']).length == 0
        order = {}
      else
        # Normalize the part number - Lumber sends a ton of leading zeros which we don't have in the entry.
        order = order['order']
        
        order['order_lines'].each do |ol|
          ol['ordln_puid'] = normalize_part_number(ol['ordln_puid'])
        end
      end
      @order_cache[po] = order
    end

    line_number = nil
    if !order.blank?
      line_number = order['order_lines'].find {|line| line['ordln_puid'] == part}.try(:[], 'ordln_line_number')

      # For whatever reason, LL's existing costing report pads the line number to 5 digits..continue doing so
      line_number = line_number.to_s.rjust(5, "0") if line_number
    end

    line_number
  end

  def normalize_part_number part
    part.to_s.sub(/^0+/, "").upcase
  end


  def order_api_client
    @api_client ||= OpenChain::Api::OrderApiClient.new("ll")
  end

end; end; end; end;