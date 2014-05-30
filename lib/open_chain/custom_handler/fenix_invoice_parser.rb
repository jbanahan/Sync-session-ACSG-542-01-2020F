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
          number = $1
        end

        number = number.rjust(7, "0")

        if suffix.blank?
          "#{prefix}-#{number}"
        else
          "#{prefix}-#{number}-#{suffix}"
        end
      end
      
      #don't call this, use the static parse method
      def initialize rows, opts
        invoice = nil
        find_and_process_invoice(rows.first) do |yielded_invoice|
          invoice = yielded_invoice
          make_header invoice, rows.first

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
        def make_header inv, row
          inv.broker_invoice_lines.destroy_all #clear existing lines
          inv.broker_reference = safe_strip row[9]
          inv.currency = safe_strip row[10]
          inv.invoice_date = Date.strptime safe_strip(row[0]), '%m/%d/%Y'
          inv.customer_number = customer_number(safe_strip(row[1]), inv.currency)
        end

        def find_and_process_invoice row
          broker_reference = safe_strip row[9]
          # We need a broker reference in the system to link to an entry, so that we can then know which 
          # customer the invoice belongs to
          if broker_reference.blank?
            raise "Invoice # #{FenixInvoiceParser.get_invoice_number(row)} is missing a broker reference number."
          end

          invoice = nil
          Lock.acquire(Lock::FENIX_INVOICE_PARSER_LOCK, times: 3) do 
            invoice = BrokerInvoice.where(:source_system=>'Fenix',:invoice_number=>FenixInvoiceParser.get_invoice_number(row)).first

            # Fall back to using the "legacy" invoice number for the time being (at a sufficient time in the future we could probably remove this)
            unless invoice || row[3].to_s.blank?
              invoice = BrokerInvoice.where(:source_system=>'Fenix',:invoice_number=>row[3].to_s.strip).first

              unless invoice
                invoice = BrokerInvoice.create! :source_system=>'Fenix',:invoice_number=>FenixInvoiceParser.get_invoice_number(row)
              end
            end
          end

          if invoice
            Lock.with_lock_retry(invoice) do
              yield invoice
            end
          end
        end

        def add_detail invoice, row
          charge_code = safe_strip row[6]
          charge_code_prefix = charge_code.split(" ").first
          charge_code = charge_code_prefix if charge_code_prefix.match /^[0-9]*$/
          line = invoice.broker_invoice_lines.build(:charge_description=>safe_strip(row[7]),:charge_code=>charge_code,:charge_amount=>BigDecimal(safe_strip(row[8])))
          line.charge_type = (['1', '2', '20','21'].include?(line.charge_code) ? 'D' : 'R')
          line
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
          return val.blank? ? val : val.strip
        end

        def create_intacct_invoice invoice
          r = IntacctReceivable.where(company: "vcu", invoice_number: invoice.invoice_number).first_or_create!
          Lock.with_lock_retry(r) do
            # If the data has already been uploaded to Intacct, then there's nothing we can do to update it (at least for now)
            return unless r.intacct_upload_date.nil?

            r.invoice_date = invoice.invoice_date
            # Use the xref value if there is one, otherwise use the raw value from Fenix
            xref = DataCrossReference.find_intacct_customer_number 'Fenix', invoice.customer_number
            r.customer_number = (xref.blank? ? invoice.customer_number : xref)

            # There are certain customers that are billed in Fenix for a third system, ALS.  These cusotmers are stored in an xref,
            # if the name is there, then the company is 'als', otherwise it's 'vcu'

            r.company = DataCrossReference.has_key?(r.customer_number, DataCrossReference::FENIX_ALS_CUSTOMER_NUMBER) ? "als" : "vcu"
            r.currency = invoice.currency

            actual_charge_sum = BigDecimal.new 0
            invoice.broker_invoice_lines.each do |line|
              actual_charge_sum += line.charge_amount

              pl = r.intacct_receivable_lines.build
              pl.charge_code = "#{line.charge_code}".rjust(3, "0")
              pl.charge_description = line.charge_description
              pl.amount = line.charge_amount
              pl.line_of_business = "Brokerage"
              pl.broker_file = invoice.entry.entry_number unless invoice.entry.nil?
              pl.location = "Toronto"
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
          OpenChain::CustomHandler::Intacct::IntacctClient.delay.async_send_dimension 'Broker File', invoice.entry.entry_number, invoice.entry.entry_number unless invoice.entry.nil?
        end
    end
  end
end
