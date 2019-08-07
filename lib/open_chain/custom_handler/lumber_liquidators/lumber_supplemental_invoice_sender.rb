require 'open_chain/custom_handler/lumber_liquidators/lumber_summary_invoice_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberSupplementalInvoiceSender
  include OpenChain::CustomHandler::LumberLiquidators::LumberSummaryInvoiceSupport

  def self.sync_code
    'LL SUPPLEMENTAL'
  end

  # This should be run daily at midnight.
  def self.run_schedulable
    sender = self.new

    # What we need to do is ONLY send invoices that were created AFTER the cost file for an entry that has already been sent.
    # This will mean that the entry will have an LL COST Report sync record but the individual invoices will not, since
    # the costing report adds sync records for every invoice it sends out at the invoice level and entry level.
    invoices = BrokerInvoice.
      joins(BrokerInvoice.need_sync_join_clause(sync_code)).
      joins(ActiveRecord::Base.sanitize_sql_array(["INNER JOIN sync_records cost_sync ON cost_sync.trading_partner = ?" + 
            " AND cost_sync.syncable_type = 'Entry' AND cost_sync.syncable_id = broker_invoices.entry_id", OpenChain::CustomHandler::LumberLiquidators::LumberCostingReport.sync_code])).
      joins(ActiveRecord::Base.sanitize_sql_array(["LEFT OUTER JOIN sync_records inv_cost_sync ON inv_cost_sync.trading_partner = ?" + 
            " AND inv_cost_sync.syncable_type = 'BrokerInvoice' AND inv_cost_sync.syncable_id = broker_invoices.id", OpenChain::CustomHandler::LumberLiquidators::LumberCostingReport.sync_code])).
      where(customer_number: "LUMBER", source_system: "Alliance").where("suffix IS NOT NULL AND LENGTH(TRIM(suffix)) > 0").
      where("sync_records.id IS NULL OR sync_records.sent_at IS NULL").
      where("inv_cost_sync.id IS NULL")


    invoices.each do |invoice|
      # Don't send invoices for entries that have failed business rules
      sender.send_invoice(invoice) unless invoice.entry.any_failed_rules?
    end
  end

  def send_invoice invoice
    wb = generate_invoice invoice

    Tempfile.open([invoice.invoice_number, ".xls"]) do |file|
      Attachment.add_original_filename_method file, "VFI Supplemental Invoice #{invoice.invoice_number}.xls"
      wb.write file
      file.flush
      file.rewind

      ActiveRecord::Base.transaction do
        sr = invoice.sync_records.first_or_initialize trading_partner: self.class.sync_code
        sr.sent_at = Time.zone.now
        sr.confirmed_at = (Time.zone.now + 1.minute)

        sr.save!

        OpenMailer.send_simple_html("otwap@lumberliquidators.com", "Supplemental Invoice #{invoice.invoice_number}", "Attached is the supplemental invoice # #{invoice.invoice_number}.", file, bcc: "payments@vandegriftinc.com").deliver_now
      end
    end
  end

  def generate_invoice invoice
    wb, sheet = XlsMaker.create_workbook_and_sheet invoice.invoice_number, []
    generate_supplemental_summary_page sheet, invoice
    wb
  end

end; end; end; end