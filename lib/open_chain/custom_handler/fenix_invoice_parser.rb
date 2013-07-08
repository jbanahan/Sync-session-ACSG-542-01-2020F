require 'open_chain/integration_client_parser'
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
        rescue
          $!.log_me ["Failed to process Fenix Invoice # #{get_invoice_number(rows.first)}" + (opts[:key] ? " from file '#{opts[:key]}'" : "") + "."]
        end
      end

      def self.get_invoice_number row
        val = row[3]
        val.nil? ? nil : val.strip
      end
      
      #don't call this, use the static parse method
      def initialize rows, opts
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
    end
  end
end
