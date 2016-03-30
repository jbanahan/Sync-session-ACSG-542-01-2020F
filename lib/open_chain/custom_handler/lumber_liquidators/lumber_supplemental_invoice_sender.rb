require 'open_chain/custom_handler/lumber_liquidators/lumber_summary_invoice_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberSupplementalInvoiceSender
  include OpenChain::CustomHandler::LumberLiquidators::LumberSummaryInvoiceSupport

  # This should be run daily at midnight.
  def self.run_schedulable
    sender = self.new

    # Normally, I'd want to have the sync records associated directly with the BrokerInvoices, but since the entry parser does a full delete/recreation of
    # the broker invoices 
    # We're ONLY sending invoices when the sync record either doesn't exist or the sent at is nil (.ie a forced resend)
    # We don't want to resend in the cases where the invoices may have update dates, LL only wants invoices sent a single time ever.
    invoices = BrokerInvoice.
      joins(BrokerInvoice.need_sync_join_clause('LL SUPPLEMENTAL')).
      where(customer_number: "LUMBER").where("suffix IS NOT NULL AND LENGTH(TRIM(suffix)) > 0").
      where("sync_records.id IS NULL OR sync_records.sent_at IS NULL")


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
        sr = invoice.sync_records.first_or_initialize trading_partner: "LL SUPPLEMENTAL"
        sr.sent_at = Time.zone.now
        sr.confirmed_at = (Time.zone.now + 1.minute)

        sr.save!

        OpenMailer.send_simple_html("otwap@lumberliquidators.com", "Supplemental Invoice #{invoice.invoice_number}", "Attached is the supplemental invoice # #{invoice.invoice_number}.", file).deliver!
      end
    end
  end

  def generate_invoice invoice
    wb, sheet = XlsMaker.create_workbook_and_sheet invoice.invoice_number, []
    generate_supplemental_summary_page sheet, invoice
    wb
  end

end; end; end; end