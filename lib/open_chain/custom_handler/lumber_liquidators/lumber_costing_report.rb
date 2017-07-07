require 'digest'
require 'open_chain/polling_job'
require 'open_chain/ftp_file_support'
require 'open_chain/api/order_api_client'
require 'open_chain/custom_handler/lumber_liquidators/lumber_cost_file_calculations_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberCostingReport
  include OpenChain::PollingJob
  include OpenChain::FtpFileSupport
  include ActionView::Helpers::NumberHelper
  include OpenChain::CustomHandler::LumberLiquidators::LumberCostFileCalculationsSupport

  def self.run_schedulable
    self.new.run
  end

  def self.sync_code
    "LL_COST_REPORT"
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
    begin
      find_entry(id) do |entry|
        if has_manual_po?(entry)
          send_manual_po(entry)
        else
          send_cost_file(entry)
        end
      end
    rescue => e
      raise e if Rails.env.test?
      e.log_me
    end
  end

  def send_cost_file entry
    entry, data = generate_entry_data(entry)
    if !data.blank?
      sync_record = entry.sync_records.where(trading_partner: self.class.sync_code).first_or_initialize

      # There should never be a sync record already existing, since we should NEVER send data for invoices that we've already sent data for
      return if sync_record.persisted?

      Tempfile.open(["Cost_", ".txt"]) do |temp|
        Attachment.add_original_filename_method temp, "Cost_#{entry.broker_reference}_#{ActiveSupport::TimeZone["America/New_York"].now.strftime("%Y-%m-%d")}.txt"
        
        data.each do |row|
          temp << row.to_csv(col_sep: "|")
        end
        temp.flush
        temp.rewind

        ftp_sync_file temp, sync_record
        now = Time.zone.now
        conf = now + 1.minute
        sync_record.sent_at = now
        sync_record.confirmed_at = conf
        sync_record.save!

        # We also need to add sync records for all the broker invoices that were sent too, so that the invoice report can know EXACTLY which
        # invoices where included on the cost files.  We can assume every invoice that's currently on the entry is included in the cost file.
        entry.broker_invoices.each do |inv|
          sr = inv.sync_records.find {|sr| sr.trading_partner == self.class.sync_code}
          if sr
            sr.update_attributes! sent_at: now, confirmed_at: conf, ftp_session: sync_record.ftp_session
          else
            inv.sync_records.create! trading_partner: self.class.sync_code, sent_at: now, confirmed_at: now, ftp_session: sync_record.ftp_session
          end
        end
      end
    end
  end

  def find_entry_ids start_time
    # Not ALL the rules for when to send data are in here...there's a couple rules that aren't well suited for SQL
    # that are evaulated later during the generate pass.  In other words, not every result returned by this query
    # will get sent.
    
    # Data should be sent ONLY ONCE
    v = Entry.select("DISTINCT entries.id").
          # We have to have broker invoices before we send this data
          joins(:broker_invoices).
          joins("LEFT OUTER JOIN sync_records sync ON sync.syncable_id = entries.id AND sync.syncable_type = 'Entry' and sync.trading_partner = 'LL_COST_REPORT'").
          where(source_system: "Alliance", customer_number: "LUMBER").
          # Goods exported by truck from CA are handled by manually emailing the invoices to LL's AR department so they
          # should not have cost files generated for them
          where("entries.transport_mode_code <> '30' OR entries.export_country_codes <> 'CA'").
          # Lumber wants these at the LATEST when Arrival Date is 3 days out...day count logic handled in can_send_entry?
          where("entries.arrival_date IS NOT NULL").
          # If we haven't sent the file already we should send it OR if someone marks the sync record as needing to be resent (.ie sent_at is null)
          # This happens in cases where the file is audited and something is wrong in it.  The person auditing the file needs to correct the file / invoice
          # data and mark the sync record for resend.  Then the automated process will pick up the file again and regenerate it with the fixed data.
          where("sync.id IS NULL OR sync.sent_at IS NULL")
    v.pluck :id
  end

  def find_entry entry_id
    Entry.transaction do 
      entry = Entry.lock.where(id: entry_id).includes(commercial_invoices: [commercial_invoice_lines: [:commercial_invoice_tariffs]], broker_invoices: [:broker_invoice_lines]).first
      yield entry
    end
  end

  def has_manual_po? entry
    entry.commercial_invoices.each do |i|
      i.commercial_invoice_lines.each do |l|
        return true if l.po_number.to_s.strip.upcase == "MANUAL"
      end
    end

    false
  end

  def send_manual_po entry
    # In this case, the entry has been flagged as needing to be manually billed.  Manually billed means
    # that we cannot build a cost file for the entry.  This is pretty much exclusively because a part on the entry
    # does not appear on a LL PO - this tends to happen on sample shipments.  In this case, the billing files will be 
    # emailed to Lumber and they will handle it on their end.
    invoices = []
    begin
      entry.attachments.where(attachment_type: "BILLING INVOICE").each do |attachment|
        invoices << attachment.download_to_tempfile
      end

      body = "<p>Please find attached #{invoices.length} invoice #{"document".pluralize(invoices.length)} for Entry # #{entry.entry_number}.</p>"
      body += "<p>This entry contains shipment information that cannot be found on a Lumber Liquidators Purchase Order and, therefore, cannot be sent via the standard cost file interface.</p>"
      body += "<p>Please find attached to this email the following #{"attachment".pluralize(invoices.length)}:<ul>"
      invoices.each {|i| body += "<li>#{i.original_filename}</li>" }
      body += "</ul></p>"
      OpenMailer.send_simple_html("ll-ap@vandegriftinc.com", "Manual Billing for File # #{entry.broker_reference}", body.html_safe, invoices, reply_to: "ll-support@vandegriftinc.com").deliver!

      # We need to add a sync record SOLELY for the entry.  We don't add any for the invoices since we didn't invoice them via the cost report.
      sr = entry.sync_records.first_or_initialize trading_partner: self.class.sync_code
      sr.update_attributes! sent_at: Time.zone.now, confirmed_at: (Time.zone.now + 1.minute)
    ensure
      invoices.each do |file|
        file.close! if file && !file.closed?
      end
    end
  end

  def generate_entry_data entry
    entry_data = []
    values = []

    if can_send_entry?(entry)
      
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


          line_values = calculate_proration_for_lines(line, total_entered_value, charge_totals, charge_buckets)

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

      add_remaining_proration_amounts values, charge_buckets
      

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

  def can_send_entry? entry
    # Some extra rules that are just easier to do in code than in the query.
    send = false
    # Can't send if the entry has any failing business rules
    if entry.failed_business_rules.length == 0

      entry.broker_invoices.each do |inv|
        # We can send if we find any invoice having an Ocean Freight (0004) charge 
        line = inv.broker_invoice_lines.find {|c| c.charge_code  == "0004"}
        if line
          send = true
          break
        end
      end

      # If there hasn't been a freight billing and we're <= 3 days out on arrival, then send.
      if !send 
        send = entry.arrival_date && ((Time.zone.now.to_date + 3.days) >= entry.arrival_date.to_date)
      end
    end

    send
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