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
      data[:order_id] = search_xl(sheet, /Order ID/i, column: 4)[:data]
      data[:order_number] = safe_row(sheet, search_xl(sheet, /PurchaseOrderNo/i, column: 7)[:row])[9]
      data[:order_date] = safe_row(sheet, search_xl(sheet, /Date/i, column: 7)[:row])[9]
      data[:ship_terms] = search_xl(sheet, /F\.O\.B\. Terms/i, column: 1, data_position: :bottom)[:data]
      data[:order_status] = search_xl(sheet, /Order Status/i, column: 4, data_position: :bottom)[:data]
      data[:ship_via] = search_xl(sheet, /Ship Via/i, column: 5, data_position: :bottom)[:data]
      data[:expected_delivery_date] = search_xl(sheet, /Expected Delivery Date/i, column: 7, data_position: :bottom)[:data]
      data[:payment_terms] = search_xl(sheet, /Payment Terms/i, column: 9, data_position: :bottom)[:data]
      data[:vendor] = parse_party "Vendor", search_xl(sheet, /Vendor:?\s*$/i, column: 1, data_position: :bottom)[:data], safe_row(sheet, search_xl(sheet, /Vendor Number:?/i, column: 1)[:row])[3]
      data[:factory] = parse_party "Factory", search_xl(sheet, /Factory:?/i, column: 5, data_position: :bottom)[:data]
      data[:forwarder] = parse_party "Forwarder", search_xl(sheet, /Forwarder:?/i, column: 1, data_position: :bottom)[:data]
      data[:consignee] = parse_party "Consignee", search_xl(sheet, /Consignee Notify:?/i, column: 4, data_position: :bottom)[:data]
      data[:final_dest] = parse_party "Final Destination", search_xl(sheet, /Final Destination:?/i, column: 8, data_position: :bottom)[:data]

      data[:items] = []
      last_row = sheet.last_row.idx
      item_header_row = search_xl(sheet, /Item Code/i, column: 0)[:row]

      if item_header_row
        ((item_header_row + 1)..last_row).each do |row_number|
          row = sheet.row row_number

          if has_item_data? row
            data[:items] << parse_item_data(row)
          elsif order_balance_row? row
            data[:order_balance] = row[10]
            # If we got the order balance there's nothing left in the spreadsheet to look for
            break
          end
        end
      end

      # Pull up the first warehouse code value from the details to the header
      data[:warehouse_code] = data[:items].find {|i| i[:warehouse_code].blank? ? nil : i[:warehouse_code]}.try(:[], :warehouse_code)

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
      add_element root, "WarehouseCode", po[:warehouse_code]
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

      def safe_row sheet, row
        row.nil? ? [] : sheet.row(row)
      end

      def search_xl sheet, search_expression, opts={}
        opts = {starting_row: 0, data_position: :right, column: 0}.merge opts

        found = {}
        (opts[:starting_row]..sheet.last_row.idx).each do |x|
          col_val = sheet.row(x)[opts[:column]]

          matched = false
          if search_expression.respond_to?(:match)
            matched = search_expression.match(col_val.to_s)
          else 
            matched = col_val == search_expression
          end

          if matched
            found[:row] = x
            data = nil
            case opts[:data_position]
            when :top
              data = sheet.row(x - 1)[opts[:column]]
            when :right
              data = sheet.row(x)[opts[:column] + 1]
            when :bottom
              data = sheet.row(x + 1)[opts[:column]]
            when :left
              data = sheet.row(x)[opts[:column] - 1]
            end
            found[:data] = data

            return found
          end
        end
        found
      end

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
        row && row[8].is_a?(String) && row[8].upcase =~ /ORDER TOTAL/
      end

  end
end; end; end;