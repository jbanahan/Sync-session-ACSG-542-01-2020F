require 'spreadsheet'
require 'open_chain/xml_builder'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module ShoesForCrews; class ShoesForCrewsPoSpreadsheetHandler
  include OpenChain::IntegrationClientParser
  include OpenChain::XmlBuilder
  include OpenChain::FtpFileSupport
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def self.parse_file data, log, opts = {}
    self.new.parse_file(data, log, opts)
  end

  SHOES_SYSTEM_CODE ||= "SHOES"

  def initialize
    @cdefs = self.class.prep_custom_definitions([:prod_part_number, :ord_line_color, :ord_line_size, :ord_line_destination_code, :ord_destination_codes])
  end

  def ftp_credentials
    ftp2_vandegrift_inc 'to_ecs/Shoes_For_Crews/PO'
  end

  def parse_file data, log, opts = {}
    write_xml(data, log, opts) {|f| ftp_file f}
  end

  def write_xml data, log, opts = {}
    log.company = importer
    log.error_and_raise "Company with system code #{SHOES_SYSTEM_CODE} not found." unless @importer

    po_data = parse_spreadsheet data

    process_po po_data, log, opts[:bucket], opts[:key]

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
        elsif has_alternate_po_number? row
          data[:alternate_po_number] = row[1]
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

  def process_po data, log, bucket, key
    status, po = *save_po(data, log, bucket, key)

    case status
    when "new"
      po.freeze_all_custom_values_including_children

      po.post_create_logic! user
      fingerprint_handling po, user
      po.create_snapshot User.integration, nil, key
    when "updated"
      po.freeze_all_custom_values_including_children

      fingerprint_handling(po, user) do
        po.post_update_logic! user
      end
      po.create_snapshot User.integration, nil, key
    when "shipping"
      # We'll probably want to, at some point, send out an email like the jill 850 parser to notify order couldn't be updated.
    end
  end

  def save_po data, log, bucket, key
    po = nil
    update_status = nil

    order_number = get_order_number(data)

    log.reject_and_raise "An order number must be present in all files.  File #{File.basename(key)} is missing an order number." if order_number.blank?

    # I'm not entirely sure why, but I keep getting duplicate products when I'm creating products inside the find_order transaction/lock.
    # I'm guessing it has to do w/ multiple distinct transactions running and then being merged at the same time, each distinct transaction
    # having its own newly created product (which wouldn't happen if we had a unique index).  
    # By running the product lookups outside of a containing transaction, this should prevent that from happening.

    products = find_all_products data[:items]

    find_order(order_number) do |existing_order, order|
      log.add_identifier InboundFileIdentifier::TYPE_PO_NUMBER, order_number, module_type:Order.to_s, module_id:order.id
      po = order

      order.customer_order_number = order_number
      order.order_date = parse_date(data[:order_date])
      order.mode = data[:ship_via]
      order.first_expected_delivery_date = parse_date(data[:expected_delivery_date])
      order.terms_of_sale = data[:payment_terms]
      order.vendor = find_vendor(data[:vendor][:number], data[:vendor][:name])
      order.last_file_bucket = bucket
      order.last_file_path = key

      if existing_order
        if order.shipping? || order.booked?
          update_status = "shipping"
          break
        else
          update_status = "updated"
          # We probably could use the upc and actually do line updates, but this is just easier
          order.order_lines.destroy_all
        end
      else
        update_status = "new"
      end

      line_number = 0
      destination_codes = Set.new
      data[:items].each do |item|
        product = products[item[:item_code]]
        line = order.order_lines.build
        line.line_number = (line_number += 1)
        line.product = product
        line.sku = item[:upc]
        line.quantity = BigDecimal(item[:ordered].to_s.strip)
        line.price_per_unit = BigDecimal(item[:unit_cost].to_s.strip)
        if item[:warehouse_code].present?
          line.find_and_set_custom_value(@cdefs[:ord_line_destination_code], item[:warehouse_code])
          destination_codes << item[:warehouse_code]
        end
        size, color = extract_size_color_from_model_description item[:model]
        line.find_and_set_custom_value(@cdefs[:ord_line_size], size) unless size.blank?
        line.find_and_set_custom_value(@cdefs[:ord_line_color], color) unless color.blank?
      end

      order.find_and_set_custom_value(@cdefs[:ord_destination_codes], destination_codes.to_a.sort.join(",")) unless destination_codes.length == 0

      # If we don't mark the order as accepted, they will not be able to be selected on the shipment screen.
      # As S4C doesn't have an acceptance step, we're safe to accept everything coming through here.
      # We're also bypassing the standard accept because we don't want to kick out acceptance comments to 
      # everyone for these, since, again, there's no acceptance step
      order.mark_order_as_accepted
      order.save!
    end

    return [update_status, po]
  end

  private 

    def get_order_number data
      order_number = data[:order_number]
      order_number = data[:alternate_po_number] if order_number.blank?

      order_number
    end

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

    def parse_date d
      v = nil
      if d.respond_to?(:acts_like_date?)
        v = d
      else
        string_val = d.to_s
        if string_val =~ /\d{1,2}\/\d{1,2}\/\d{4}/
          v = Date.strptime string_val, "%d/%m/%Y"
        elsif string_val =~ /\d{4}\/\d{1,2}\/\d{1,2}/
          v = Time.zone.parse(string_val).to_date
        end
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

    def has_alternate_po_number? row
      row && !row[1].blank?
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

    def extract_size_color_from_model_description description
      case description
      when /.*\s*-\s*Size\s*(.*),\s*(.*)$/i # Venice - Size 07, Blk -> model + color + size = .*\s*-\s*Size\s*(.*),\s*(.*)$
        [$1, $2]
      when /.*\s*-\sSize\s*(.*)$/i # Comfort Max II Casual Insoles - Size 07 ->  model + size = .*\s*-\sSize\s*(.*)$
        [$1, nil]
      when /.*\s*-\s*(.*)$/i # Anti Fatigue Ultra Mat - Blk -> model + color = .*\s*-\s*(.*)$
        [nil, $1]
      else
        nil
      end
    end

    def find_order order_number
      order = nil
      existing = true
      Lock.acquire("Order-SHOES-"+order_number) do 
        order = Order.where(order_number: "#{SHOES_SYSTEM_CODE}-#{order_number}", importer_id: importer.id).first_or_create! {|order| existing = false }
      end

      if order
        Lock.with_lock_retry(order) do 
          yield existing, order
        end
      end
    end

    def importer
      @importer ||= Company.importers.where(system_code: SHOES_SYSTEM_CODE).first
      @importer
    end

    def user
      @user ||= User.integration
      @user
    end

    def find_vendor vendor_id, name
      return nil if vendor_id.blank?

      vendor = Company.vendors.where(system_code: "#{SHOES_SYSTEM_CODE}-#{vendor_id}").joins("INNER JOIN linked_companies lc ON lc.parent_id = #{importer.id}").first
      if vendor.nil?
        vendor = Company.create! system_code: "#{SHOES_SYSTEM_CODE}-#{vendor_id}", name: name, vendor: true
        importer.linked_companies << vendor
      end

      vendor
    end

    def find_all_products items
      products = {}
      items.each do |item|
        products[item[:item_code]] = find_product item
      end
      products
    end

    def find_product item
      unique_identifier = "#{SHOES_SYSTEM_CODE}-#{item[:item_code]}"
      product = nil

      Lock.acquire("#{importer.id}-#{unique_identifier}") do 
        product = Product.where(importer_id: importer.id, unique_identifier: "#{SHOES_SYSTEM_CODE}-#{item[:item_code]}").first_or_create!
      end
      
      Lock.with_lock_retry(product) do 
        part_cv = product.find_and_set_custom_value @cdefs[:prod_part_number], item[:item_code]
        product.name = item[:model]
        product.unit_of_measure = item[:case_uom]

        if product.changed? || part_cv.changed?
          product.save!
          product.freeze_all_custom_values_including_children
          product.create_snapshot user
        end
      end
      
      product
    end

    def order_fingerprint po, user
      fingerprint_fields = {model_fields: [:ord_ord_num, :ord_cust_ord_no, :ord_ord_date, :ord_mode, :ord_first_exp_del, :ord_terms, :ord_ven_syscode],
        order_lines: {
          model_fields: [:ordln_line_number, :ordln_puid, :ordln_sku, :ordln_ordered_qty, :ordln_ordln_ppu, @cdefs[:ord_line_destination_code].model_field_uid, @cdefs[:ord_line_size].model_field_uid, @cdefs[:ord_line_color].model_field_uid]
        }
      }

      po.generate_fingerprint fingerprint_fields, user
    end

    def fingerprint_handling po, user
      fingerprint = order_fingerprint po, user
      xref = DataCrossReference.find_po_fingerprint po
      if xref.nil? 
        xref = DataCrossReference.create_po_fingerprint(po, fingerprint) if xref.nil?
        yield if block_given?
      elsif xref.value != fingerprint
        xref.value = fingerprint
        xref.save!
        yield if block_given?
      end
    end

end; end; end; end
