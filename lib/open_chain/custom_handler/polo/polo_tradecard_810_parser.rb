require 'rexml/document'
require 'open_chain/integration_client_parser'

module OpenChain; module CustomHandler; module Polo
  class PoloTradecard810Parser
    include PoloBusinessLogic
    include IntegrationClientParser

    def integration_folder
      "/opt/wftpserver/ftproot/www-vfitrack-net/_polo_tradecard_810"
    end

    def parse data, opts = {}
      parse_dom(REXML::Document.new(data), opts)
    end

    private 

      def parse_dom dom, opts = {}
        dom.each_element("Invoices/Invoice") do |inv_el|
          begin
            parse_invoice_element inv_el
          rescue => e
            raise e unless Rails.env == 'production'
            if opts[:key]
              e.log_me ["Parsing S3 file #{opts[:key]}"]
            else
              e.log_me
            end
          end
        end
        nil
      end

      def parse_invoice_element inv_el
        invoice_number = inv_el.text("InvoiceNumber")
        if invoice_number
          process_tradecard_invoice(invoice_number) do |invoice|
            invoice.invoice_date = inv_el.text("InvoiceDate")
            inv_el.each_element("InvoiceLine") do |line_el|
              line = invoice.commercial_invoice_lines.build
              line.po_number = line_el.text("OrderNumber")
              line.part_number = line_el.text("PartNumber")
              line.unit_of_measure = line_el.text("UnitOfMeasue")
              line.quantity = parse_decimal line_el.text("Quantity")
            end

            invoice.save!
          end
        end
      end

      def process_tradecard_invoice invoice_number
        invoice = CommercialInvoice.where(invoice_number: invoice_number, vendor_name: "Tradecard").includes(:commercial_invoice_lines).first_or_create!
        if invoice
          CommercialInvoice.transaction do 
            invoice.commercial_invoice_lines.destroy_all
            yield invoice
          end
        end
      end

      def parse_date val
        val.blank? ? nil : Date.strptime(val, "%y%m%d") 
      rescue
        nil
      end

      def parse_decimal val
        val.blank? ? nil : BigDecimal.new(val.strip)
      rescue
        BigDecimal.new(0)
      end

  end
end; end; end