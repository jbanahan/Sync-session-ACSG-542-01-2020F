require 'spreadsheet'
require 'open_chain/xml_builder'

module OpenChain; module CustomHandler; module ShoesForCrews; 
  class ShoesForCrewsPoSpreadsheetHandler
    include OpenChain::IntegrationClientParser
    include OpenChain::XmlBuilder
    include OpenChain::FtpFileSupport

    def ftp_credentials
      ftp2_vandegrift_inc 'to_ecs/Shoes_For_Crews/PO'
    end

    def parse data, opts = {}
      write_xml(data) {|f| ftp_file f}
    end

    def write_xml data
      po_data = parse_spreadsheet data
      xml_document = build_xml po_data
      Tempfile.open(["ShoesForCrewsPO", ".xml"]) do |f|
        xml_document.write f
        f.flush
        yield f if block_given?
        f
      end
    end

    def parse_spreadsheet data
      sheet = Spreadsheet.open(StringIO.new(data)).worksheet 0

      data = {}
      data[:order_id] = sheet.row(3)[5]
      data[:order_number] = sheet.row(4)[9]
      data[:order_date] = sheet.row(5)[9]
      data[:ship_terms] = sheet.row(9)[1]
      data[:order_status] = sheet.row(9)[4]
      data[:ship_via] = sheet.row(9)[5]
      data[:expected_delivery_date] = sheet.row(9)[7]
      data[:payment_terms] = sheet.row(9)[9]
      data[:vendor] = parse_party "Vendor", sheet.row(7)[1], sheet.row(4)[3]
      data[:factory] = parse_party "Factory", sheet.row(7)[5]
      data[:forwarder] = parse_party "Forwarder", sheet.row(11)[1]
      data[:consignee] = parse_party "Consignee", sheet.row(11)[4]
      data[:final_dest] = parse_party "Final Destination", sheet.row(11)[8]

      data[:items] = []
      last_row = sheet.last_row.idx
      (13..last_row).each do |row_number|
        row = sheet.row row_number


        if has_item_data? row
          data[:items] << parse_item_data(row)
        elsif order_balance_row? row
          data[:order_balance] = row[10]
          # If we got the order balance there's nothing left in the spreadsheet to look for
          break
        end
      end

      data
    end

    def build_xml po
      doc, root = build_xml_document "PurchaseOrder"
      add_element root, "OrderId", po[:order_id]
      add_element root, "OrderNumber", po[:order_number]
      add_element root, "OrderDate", date_string(po[:order_date])
      add_element root, "FobTerms", po[:ship_terms]
      add_element root, "OrderStatus", po[:order_status]
      add_element root, "ShipVia", po[:ship_via]
      add_element root, "ExpectedDeliveryDate", date_string(po[:expected_delivery_date])
      add_element root, "PaymentTerms", po[:payment_terms]
      add_element root, "OrderBalance", po[:order_balance]
      add_party_xml root, po[:vendor]
      add_party_xml root, po[:factory]
      add_party_xml root, po[:forwarder]
      add_party_xml root, po[:consignee]
      add_party_xml root, po[:final_dest]

      items = add_element root, "Items"
      po[:items].each do |item|
        add_item_xml items, item
      end

      doc
    end

    private 

      def add_party_xml parent_element, party
        p = add_element parent_element, "Party"
        add_element p, "Type", party[:type]
        if party[:number]
          add_element p, "Number", party[:number]
        end
        add_element p, "Name", party[:name]
        add_element p, "Address", party[:address], cdata: true
      end

      def add_item_xml parent_element, i
        item = add_element parent_element, "Item"
        add_element item, "ItemCode", i[:item_code]
        add_element item, "WarehouseCode", i[:warehouse_code]
        add_element item, "Model", i[:model]
        add_element item, "UpcCode", i[:upc]
        add_element item, "Unit", i[:unit]
        add_element item, "Ordered", i[:ordered]
        add_element item, "UnitCost", i[:unit_cost]
        add_element item, "Amount", i[:amount]
        add_element item, "Case", i[:case]
        add_element item, "CaseUom", i[:case_uom]
        add_element item, "NumberOfCases", i[:num_cases]
      end

      def date_string d
        v = nil
        if d.respond_to? :strftime
          v = d.strftime "%Y-%m-%d"
        else
          v = d.to_s
        end

        v
      end

      def parse_party type, address_lines, number = nil
        data = {}
        data[:type] = type
        data[:number] = number if number
        lines = (address_lines.is_a?(String)) ? address_lines.split(/\r?\n/) : nil
        if lines
          data[:name] = lines[0]
          data[:address] = lines[1..-1].join("\n")
        end

        data
      end

      def has_item_data? row
        # Column 5 is the UPC code, which should never be blank except on the pointless prepack lines they have on the 
        row && !row[5].blank?
      end

      def parse_item_data row
        data = {}
        data[:item_code] = row[0]
        data[:warehouse_code] = row[2]
        data[:model] = row[4]
        data[:upc] = row[5]
        data[:unit] = row[6]
        data[:ordered] = row[7]
        data[:unit_cost] = row[8]
        data[:amount] = row[9]
        data[:case] = row[10]
        data[:case_uom] = row[11]
        data[:num_cases] = row[12]

        data
      end

      def first_summary_row? row
        row && row[8].upcase == 'NET ORDER'
      end

      def order_balance_row? row
        row && row[8].is_a?(String) && row[8].upcase == "ORDER BALANCE"
      end

  end
end; end; end;