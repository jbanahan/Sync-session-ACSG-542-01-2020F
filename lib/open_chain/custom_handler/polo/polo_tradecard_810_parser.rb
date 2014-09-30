require 'rexml/document'
require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/custom_handler/polo/polo_850_vandegrift_parser'

module OpenChain; module CustomHandler; module Polo
  class PoloTradecard810Parser
    include PoloBusinessLogic
    include IntegrationClientParser
    include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

    def initialize
      @cdefs = self.class.prep_custom_definitions [:ord_invoicing_system, :ord_invoiced]
    end

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
          invoice = process_tradecard_invoice(invoice_number) do |invoice|
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

          if invoice
            po_numbers = invoice.commercial_invoice_lines.map {|l| l.po_number.blank? ? nil : l.po_number}.uniq.compact

            po_numbers.each do |po_number|
              mark_po po_number
            end
          end
        end
      end

      def process_tradecard_invoice invoice_number
        invoice = nil
        Lock.acquire(Lock::TRADE_CARD_PARSER, times: 3) do 
          invoice = CommercialInvoice.where(invoice_number: invoice_number, vendor_name: "Tradecard").includes(:commercial_invoice_lines).first_or_create!
        end
        
        if invoice
          Lock.with_lock_retry(invoice) do 
            invoice.commercial_invoice_lines.destroy_all
            yield invoice
          end  
        end
        
        invoice
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

      def mark_po po_number
        # The PO number passed in from the XML includes the SAP line number at the end, strip it off
        if po_number =~ /(.+)-[^-]+$/
          po_number = $1
        end

        possible_order_numbers = Polo850VandegriftParser::RL_BUYER_MAP.values.map {|v| Order.compose_po_number v, po_number}

        # The unique order identifier is a composition of the importer's code + the order number
        orders = Order.where(order_number: [possible_order_numbers]).
                  joins("INNER JOIN custom_values cv ON cv.customizable_id = orders.id AND cv.customizable_type = 'Order' AND cv.custom_definition_id = #{@cdefs[:ord_invoicing_system].id} AND cv.string_value = 'Tradecard'").all

        orders.each do |order|
          order.update_custom_value! @cdefs[:ord_invoiced], true
        end
      end

  end
end; end; end