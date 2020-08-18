require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/intacct/intacct_client'
require 'open_chain/fiscal_month_assigner'

module OpenChain; module CustomHandler; class FenixInvoiceParser
  include OpenChain::IntegrationClientParser

  def self.parse_file file_content, log, opts = {}
    last_invoice_number = ''
    rows = []
    CSV.parse(file_content, headers: true) do |row|
      my_invoice_number = get_invoice_number row
      next unless my_invoice_number

      if last_invoice_number != my_invoice_number && !rows.empty?
        process_invoice_rows rows, log, opts
        rows = []
      end
      rows << row
      last_invoice_number = my_invoice_number
    end
    process_invoice_rows rows, log, opts unless rows.empty?
  end

  def self.process_invoice_rows rows, log, opts
      self.new.process_invoice_data rows, log, opts
  rescue StandardError => e
      e.log_me ["Failed to process Fenix Invoice # #{get_invoice_number(rows.first)}" + (opts[:key] ? " from file '#{opts[:key]}'" : "") + "."]
  end

  def self.get_invoice_number row
    return nil if row[3].blank?

    prefix = row[2].to_s.strip.rjust(2, "0")
    number = row[3].to_s.strip
    suffix = row[4].to_s.strip.rjust(2, "0")

    if suffix =~ /^0+$/
      suffix = ""
    end

    # Looks like the invoice number includes the suffix, but in a way that doesn't zero pad it so we need to strip out
    # everything after the trailing hyphen
    if number =~ /^(.+)-\w+$/
      number = Regexp.last_match(1)
    end

    number = number.rjust(7, "0")

    if suffix.blank?
      "#{prefix}-#{number}"
    else
      "#{prefix}-#{number}-#{suffix}"
    end
  end

  # don't call this, use the static parse method
  def process_invoice_data rows, log, opts
    invoice = nil
    entry_number = nil

    find_and_process_invoice(rows.first, log) do |yielded_invoice|
      invoice = yielded_invoice
      make_header invoice, rows.first
      entry_number = rows.first[5].to_s.strip

      invoice.last_file_bucket = opts[:bucket]
      invoice.last_file_path = opts[:key]
      invoice.invoice_total = BigDecimal('0.00')
      rows.each do |r|
        line = add_detail(invoice, r)
        invoice.invoice_total += line.charge_amount
      end

      ent = Entry.includes(:broker_invoices).find_by(source_system: invoice.source_system, broker_reference: invoice.broker_reference)
      if ent
        ent.broker_invoices << invoice
        total_broker_invoice_value = 0.0
        ent.broker_invoices.each do |inv|
          total_broker_invoice_value += inv.invoice_total
        end
        ent.broker_invoice_total = total_broker_invoice_value
        OpenChain::FiscalMonthAssigner.assign ent
        ent.save!
        ent.create_snapshot User.integration, nil, log.s3_path
      else
        invoice.save!
      end
    end

    # Only do intacct stuff in WWW instance
    if MasterSetup.get.custom_feature?("WWW")
      create_intacct_invoice(invoice, entry_number) unless invoice.nil? || invoice.customer_number == "GENERIC"
    end
  end

  private

    def make_header inv, row
      inv.broker_invoice_lines.destroy_all # clear existing lines
      inv.broker_reference = safe_strip row[9]
      inv.currency = safe_strip row[10]
      inv.invoice_date = Date.strptime safe_strip(row[0]), '%m/%d/%Y'
      inv.customer_number = customer_number(safe_strip(row[1]), inv.currency)
      # Suffix will be blank or zero for the first invoices..so just leave it null for these
      suffix = row[4].to_i
      inv.suffix = suffix if suffix > 0
    end

    def find_and_process_invoice row, log
      invoice_number = FenixInvoiceParser.get_invoice_number(row)
      log.add_identifier :invoice_number, invoice_number

      broker_reference = safe_strip row[9]
      # We need a broker reference in the system to link to an entry, so that we can then know which
      # customer the invoice belongs to
      if broker_reference.blank?
        log.reject_and_raise "Invoice # #{invoice_number} is missing a broker reference number."
      end

      invoice = nil
      Lock.acquire("BrokerInvoice-#{invoice_number}") do
        invoice = BrokerInvoice.where(source_system: 'Fenix', invoice_number: invoice_number).first_or_create!
      end

      if invoice
        log.set_identifier_module_info :invoice_number, BrokerInvoice, invoice.id, value: invoice_number

        Lock.db_lock(invoice) do
          yield invoice
        end
      end
    end

    def add_detail invoice, row
      charge_code = safe_strip row[6]
      charge_code_prefix = charge_code.to_s.strip.split(" ").first
      charge_code = charge_code_prefix if charge_code_prefix.to_s.match(/^[0-9]*$/)
      charge_description = safe_strip(row[7])

      # This whole check is built entirely due to a bug in Fenix where it is sending a blank
      # charge code for GST and HST tax lines.  These lines should all just be billed to
      # the 255 account.  So, lets just handle that until Fenix fixes the issue.
      if charge_code.blank? && hst_gst_charge_description?(charge_description.to_s)
        charge_code = hst_gst_default_code
      end

      raise StandardError, "Invoice # #{invoice.invoice_number} is missing a charge code for charge description #{charge_description}." if charge_code.blank?

      line = invoice.broker_invoice_lines.build(charge_description: charge_description, charge_code: charge_code, charge_amount: BigDecimal(safe_strip(row[8])))
      line.charge_type = (['1', '2', '20', '21'].include?(line.charge_code) ? 'D' : 'R')
      line
    end

    def hst_gst_charge_description? description
      # What we're looking for is basically "HST (XX)" or "GST (XX)""
      (description =~ /(?:GST|HST)\s*\([^)]+\)/i).present?
    end

    def hst_gst_default_code
      "255"
    end

    def customer_number number, currency
      # For some unknown reason, if the invoice is billed in USD, Fenix sends us the customer number with a U
      # appended to it.  So, strip the U.
      cust_no = number
      if currency && number && currency.upcase == "USD" && cust_no.upcase.end_with?("U")
        cust_no = cust_no[0..-2]
      end
      cust_no
    end

    def safe_strip val
      val.blank? ? val : val.strip
    end

    def create_intacct_invoice invoice, entry_number
      # Use the xref value if there is one, otherwise use the raw value from Fenix
      xref = DataCrossReference.find_intacct_customer_number 'Fenix', invoice.customer_number
      customer_number = (xref.presence || invoice.customer_number)
      # There are certain customers that are billed in Fenix for a third system, ALS.  These cusotmers are stored in an xref,
      # if the name is there, then the company is 'als', otherwise it's 'vcu'
      company = DataCrossReference.key?(customer_number, DataCrossReference::FENIX_ALS_CUSTOMER_NUMBER) ? "als" : "vcu"

      # If the invoice data comes in prior to the entry data coming from Fenix, then there's not going to be an Entry that the invoice
      # is associated with.  The actual invoice csv data does have the entry number in it, so we'll fall back to using
      # that data if the entry is not present.
      # In general, this shouldn't happen, but there's been a few times where B2B systems are acting wonky where this has happened.
      real_entry_number = invoice.entry&.entry_number.presence || entry_number

      r = IntacctReceivable.where(company: company, invoice_number: invoice.invoice_number).first_or_create!
      Lock.db_lock(r) do
        # If the data has already been uploaded to Intacct, then there's nothing we can do to update it (at least for now)
        return unless r.intacct_upload_date.nil?

        r.intacct_receivable_lines.destroy_all

        r.invoice_date = invoice.invoice_date
        r.customer_number = customer_number
        r.currency = invoice.currency

        actual_charge_sum = BigDecimal 0
        invoice.broker_invoice_lines.each do |line|
          actual_charge_sum += line.charge_amount

          pl = r.intacct_receivable_lines.build
          pl.charge_code = line.charge_code.to_s.rjust(3, "0")
          pl.charge_description = line.charge_description
          pl.amount = line.charge_amount
          pl.line_of_business = "Brokerage"
          pl.broker_file = real_entry_number

          # For whatever reason, a location code is tied exclusively to a single entity in Intacct.  So we need to use
          # different location codes for the same office depending on which invoicing system the customer's data originates from.
          pl.location = r.company == "als" ? "TOR" : "Toronto"
        end

        # Credit Memo or Sales Order Invoice (depends on the sum of the charges)
        # Sales Order Invoice is for all standard invoices
        # Credit Memo is for cases where we're backing out charges from a previous Sales Order Invoice
        if actual_charge_sum >= 0
          r.receivable_type = IntacctReceivable.create_receivable_type r.company, false
        else
          r.receivable_type = IntacctReceivable.create_receivable_type r.company, true
          # Credit Memos should have all credit lines as positive amounts.  The lines come to us
          # as negative amounts from Fenix
          r.intacct_receivable_lines.each {|l| l.amount = (l.amount * -1)}
        end

        r.save!
      end

      # We also want to queue up a send to push the broker file number dimension to intacct
      OpenChain::CustomHandler::Intacct::IntacctClient.delay.async_send_dimension 'Broker File', real_entry_number, real_entry_number if real_entry_number.present?
    end
end; end; end
