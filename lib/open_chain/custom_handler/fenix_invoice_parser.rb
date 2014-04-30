require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/intacct/intacct_client'

module OpenChain
  module CustomHandler
    class FenixInvoiceParser
      extend OpenChain::IntegrationClientParser
      def self.parse file_content, opts={}
        last_invoice_number = ''
        rows = []
        CSV.parse(file_content,:headers=>true) do |row|
          my_invoice_number = get_invoice_number row
          next unless my_invoice_number
          
          if last_invoice_number!=my_invoice_number && !rows.empty?
            process_invoice_rows rows, opts
            rows = []
          end
          rows << row
          last_invoice_number = my_invoice_number
        end
        process_invoice_rows rows, opts unless rows.empty?
      end

      def self.process_invoice_rows rows, opts
        begin
          self.new rows, opts
        rescue => e
          e.log_me ["Failed to process Fenix Invoice # #{get_invoice_number(rows.first)}" + (opts[:key] ? " from file '#{opts[:key]}'" : "") + "."]
        end
      end

      def self.get_invoice_number row
        val = row[3]
        val.nil? ? nil : val.strip
      end
      
      #don't call this, use the static parse method
      def initialize rows, opts
        invoice = nil
        BrokerInvoice.transaction do
          invoice = make_header rows.first
          invoice.last_file_bucket = opts[:bucket]
          invoice.last_file_path = opts[:key]
          invoice.invoice_total = BigDecimal('0.00')
          rows.each do |r|
            line = add_detail(invoice, r)
            invoice.invoice_total += line.charge_amount unless line.charge_type=='D'
          end

          ent = Entry.includes(:broker_invoices).find_by_source_system_and_broker_reference(invoice.source_system, invoice.broker_reference)
          if ent
            ent.broker_invoices << invoice
            total_broker_invoice_value = 0.0
            ent.broker_invoices.each do |inv|
              total_broker_invoice_value += inv.invoice_total
            end
            ent.broker_invoice_total = total_broker_invoice_value
            ent.save!
          else
            invoice.save!
          end
        end

        create_intacct_invoice(invoice) if invoice
      end

      private 
        def make_header row
          broker_reference = safe_strip row[9]
          # We need a broker reference in the system to link to an entry, so that we can then know which 
          # customer the invoice belongs to
          if broker_reference.blank?
            raise "Invoice # #{FenixInvoiceParser.get_invoice_number(row)} is missing a broker reference number."
          end

          inv = BrokerInvoice.where(:source_system=>'Fenix',:invoice_number=>FenixInvoiceParser.get_invoice_number(row)).first_or_create!
          inv.broker_invoice_lines.destroy_all #clear existing lines
          inv.broker_reference = broker_reference
          inv.currency = safe_strip row[10]
          inv.invoice_date = Date.strptime safe_strip(row[0]), '%m/%d/%Y'
          inv.customer_number = safe_strip row[1]
          inv
        end

        def add_detail invoice, row
          charge_code = safe_strip row[6]
          charge_code_prefix = charge_code.split(" ").first
          charge_code = charge_code_prefix if charge_code_prefix.match /^[0-9]*$/
          line = invoice.broker_invoice_lines.build(:charge_description=>safe_strip(row[7]),:charge_code=>charge_code,:charge_amount=>BigDecimal(safe_strip(row[8])))
          line.charge_type = (['20','21'].include?(line.charge_code) ? 'D' : 'R')
          line
        end

        def safe_strip val
          return val.blank? ? val : val.strip
        end

        def create_intacct_invoice invoice
          r = IntacctReceivable.where(company: "vcu", invoice_number: invoice.invoice_number).first_or_create!
          Lock.with_lock_retry(r) do
            # If the data has already been uploaded to Intacct, then there's nothing we can do to update it (at least for now)
            return unless r.intacct_upload_date.nil?

            r.invoice_date = invoice.invoice_date
            r.company = "vcu"
            # Use the xref value if there is one, otherwise use the raw value from Fenix
            xref = DataCrossReference.find_intacct_customer_number 'Fenix', invoice.customer_number
            r.customer_number = (xref.blank? ? invoice.customer_number : xref)
            r.currency = invoice.currency

            actual_charge_sum = BigDecimal.new 0
            invoice.broker_invoice_lines.each do |line|
              actual_charge_sum += line.charge_amount

              pl = r.intacct_receivable_lines.build
              pl.charge_code = line.charge_code
              pl.charge_description = line.charge_description
              pl.amount = line.charge_amount
              pl.line_of_business = "Brokerage"
              pl.broker_file = invoice.broker_reference
              pl.location = "Toronto"
            end

            # Credit Memo or Sales Order Invoice (depends on the sum of the charges)
            # Sales Order Invoice is for all standard invoices
            # Credit Memo is for cases where we're backing out charges from a previous Sales Order Invoice
            if actual_charge_sum >= 0
              r.receivable_type = IntacctReceivable::SALES_INVOICE_TYPE
            else
              r.receivable_type = IntacctReceivable::CREDIT_INVOICE_TYPE
              # Credit Memos should have all credit lines as positive amounts.  The lines come to us
              # as negative amounts from Fenix
              r.intacct_receivable_lines.each {|l| l.amount = (l.amount * -1)}
            end

            r.save!
          end

          # We also want to queue up a send to push the broker file number dimension to intacct
          OpenChain::CustomHandler::Intacct::IntacctClient.delay.async_send_dimension 'Broker File', invoice.broker_reference, invoice.broker_reference unless invoice.broker_reference.blank?
        end
    end
  end
end
