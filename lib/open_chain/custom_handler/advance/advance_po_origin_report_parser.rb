require 'open_chain/custom_handler/custom_file_csv_excel_parser.rb'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/custom_handler/mass_order_creator'
require 'spreadsheet'

module OpenChain; module CustomHandler; module Advance; class AdvancePoOriginReportParser
  include OpenChain::CustomHandler::CustomFileCsvExcelParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::CustomHandler::MassOrderCreator

  def initialize custom_file
    @custom_file = custom_file
  end

  def self.can_view? user
    MasterSetup.get.custom_feature?("alliance") && user.company.master? && user.edit_orders?
  end

  def can_view? user
    self.class.can_view? user
  end

  def process user 
    result = process_file user, @custom_file
    subject = "CQ Origin Report Complete"
    body = "The report has been processed without error."
    if result.missing_product_count > 0
      subject += " With Errors"
      body = "The report has been processed, however, #{result.missing_product_count} #{result.missing_product_count > 1 ? "products were" : "product was"} missing from VFI Track.<br>A separate email containing order and product files has been emailed to you. Follow the instructions in the email to complete the data load."
    end

    user.messages.create! subject: subject, body: body
    nil
  end

  def match_lines_method
    :ordln_puid
  end

  def valid_file?
    # The file must be an xls or xlsx file
    [".XLSX", ".XLS"].include? File.extname(@custom_file.attached_file_name).to_s.upcase
  end

  class ParseResult
    attr_reader :orders, :missing_product_count, :orders_missing_products, :header_row

    def initialize orders, missing_product_count, orders_missing_products, header_row
      @orders = orders
      @missing_product_count = missing_product_count
      @orders_missing_products = orders_missing_products
      @header_row = header_row
    end
  end

  private

    def process_file user, custom_file
      result = parse_file custom_file

      if result.orders.size > 0
        create_orders user, result.orders
      end

      missing_products_spreadsheet = nil
      orders_spreadsheet = nil
      if result.orders_missing_products.size > 0
        missing_products_spreadsheet, orders_spreadsheet, orders_only_errors_spreadsheet = create_spreadsheets result.orders_missing_products, result.header_row
      end

      if missing_products_spreadsheet
        base_file_name = File.basename(custom_file.attached_file_name)
        name = File.basename(base_file_name, ".*")

        Tempfile.open([name, ".xlsx"]) do |missing_products|
          Attachment.add_original_filename_method missing_products, "#{name} - Missing Products.xlsx"
          missing_products_spreadsheet.write missing_products

          Tempfile.open(["#{name}_orders", ".xls"]) do |orders|
            Attachment.add_original_filename_method orders, "#{name} - Orders.xlsx"
            orders_spreadsheet.write orders

            Tempfile.open(["#{name}_orders_errors", ".xls"]) do |orders_only_errors|

              Attachment.add_original_filename_method orders_only_errors, "#{name} - Order Errors.xlsx"
              orders_only_errors_spreadsheet.write orders_only_errors

              body = "Attached are the product lines that were missing from VFI Track.  Please fill out the #{missing_products.original_filename} file with all the necessary information and load the data into VFI Track, then reprocess the attached #{orders.original_filename} PO file to load the POs that were missing products into the system."
              OpenMailer.send_simple_html(user.email, "CQ Origin PO Report Result", body, [missing_products, orders, orders_only_errors]).deliver!
            end
            
          end
        end
      end

      result
    end

    def parse_file custom_file
      orders = {}
      current_order_lines = []
      current_order_missing_product = false

      header_row = nil
      orders_missing_products = []
      missing_product_count = 0

      row_number = -1
      foreach(custom_file) do |row, row_number|

        if header_row.nil?
          header_row = row
          next
        end

        #skip any line that is missing a PO Number or SKU-Number
        next if order_number(row).blank? || cq_part_number(row).blank?

        if current_order_lines.length > 0 && order_number(current_order_lines[0]) != order_number(row)
          if current_order_missing_product
            orders_missing_products.push *current_order_lines
          end

          current_order_lines.clear
          current_order_missing_product = false
        end

        current_order_lines << row

        # Find the product for this line.
        product = find_product row
        if product
          order_number = order_number(row)
          order = orders[order_number]
          if order.nil?
            order = build_order_header row
            orders[order_number] = order
          end
          order[:order_lines_attributes] << build_order_line(row, product)
          row[row.size] = false
        else
          current_order_missing_product = true
          missing_product_count += 1
          # Add an indicator to the row, which we'll strip off later to show that this particular line
          # is missing a product (we want to highlight these rows in the file we send back out)
          row[row.size] = true
        end
      end

      if current_order_lines.length > 0 && current_order_missing_product
        orders_missing_products.push *current_order_lines
      end

      ParseResult.new orders.values, missing_product_count, orders_missing_products, header_row
    end

    def create_spreadsheets orders_missing_products, header_row
      missing_products = Set.new
      orders_missing_products.each do |row|
        missing_products << [sku_number(row), cq_part_number(row)] if missing_product?(row)
      end

      [create_missing_products_workbook(missing_products), create_orders_missing_products_workbook(orders_missing_products, header_row, false), create_orders_missing_products_workbook(orders_missing_products, header_row, true)]
    end

    def create_missing_products_workbook missing_products
      builder = missing_products_builder
      sheet = builder.create_sheet "Missing Products", headers: ["AAP SKU (Item Number)", "Part Number", "CQ Line Code", "CQ SKU", "Merchandise Group Description", 
        "Merchandise Department Description", "Merchandise Class Description", "Merchandise Sub-Class Description", "Item Description", "US HTS Code", "US Duty", 
        "CAN HS Code", "CAN Duty", "Freight Cost", "Piece Per Set", "Comments"]
      builder.freeze_horizontal_rows sheet, 1

      missing_products.to_a.each do |numbers|
        builder.add_body_row sheet, [numbers[0], numbers[1], nil, nil]
      end

      builder
    end

    def create_orders_missing_products_workbook  orders_missing_products, header_row, only_errors
      builder = only_errors ? order_missing_products_only_errors_builder : orders_missing_products_builder

      sheet = builder.create_sheet "Orders Missing Products",  headers: header_row
      builder.freeze_horizontal_rows sheet, 1

      # "FFFF00" = Yellow
      missing_product_format = builder.create_style :missing_product, {bg_color: "FFFF00"}
      missing_product_date_format = builder.create_style :missing_product_date, {bg_color: "FFFF00", format_code: "YYYY-MM-DD"}

      styles = []
      header_row.length.times { styles << missing_product_format }
      [14, 15, 17, 18, 19].each {|x| styles[x] = missing_product_date_format }

      orders_missing_products.each do |row|
        next if only_errors && !missing_product?(row)

        if missing_product?(row)
          builder.add_body_row sheet, row[0..-2], styles: styles
        else
          builder.add_body_row sheet, row[0..-2]
        end
      end

      builder
    end

    def missing_product? row
      # If the last value in the row is true, it means it's missing the product line
      row[-1] === true
    end

    def find_product row
      cq_part = cq_part_number(row)
      return nil if cq_part.blank?

      # CQ Part # can potentially match to multiple products (CQ Part # is unique to the part itself, but the full value we call part number 
      # includes a prefix of the factory designator - and that full sku is what's on the Prep 7501).  We need to 
      # find the unique part based on the CQ part number from the file (you'd think we could look up the part based on the 
      # FULLCQSKU , but the origin report is missing hyphens and other punctuation from the part number, 
      # so a lookup on that isn't really feasible).  Also, because of the missing punctuation, we can't use the 
      # FullCQSKU from the file to create the Product, since it's possible that this value isn't going to match what's on the
      # Prep7501.
      products = Product.where(importer_id: importer).joins(:custom_values).where(custom_values: {custom_definition_id: cdefs[:prod_short_description].id, string_value: cq_part}).all

      return nil if products.length == 0

      found = nil
      # Strip any non-alphanumeric chars from the product's part number and see if part number from the file matches on of the ones we found.
      part = part_number(row).to_s.gsub(/[^[[:alnum:]]]/, "")
      if !part.blank?
        # Strip any non-word chars from the product's part number and see if part number from the file matches on of the ones we found.
        products.each do |product|
          if product.custom_value(cdefs[:prod_part_number]).to_s.gsub(/[^[[:alnum:]]]/, "") == part
            found = product
            break
          end
        end
      end

      found
    end

    def build_order_header row
      {ord_ord_num: "#{importer.system_code}-#{order_number(row)}", ord_cust_ord_no: order_number(row), ord_imp_id: importer.id, ord_ord_date: date_value(row[14]), order_lines_attributes: []}
    end

    def build_order_line row, product
      total_cost = decimal_value(row[12], decimal_places: 2)
      units = decimal_value(row[10], decimal_places: 2)

      unit_price = BigDecimal("0")
      if !units.nil? && units.nonzero?
        unit_price = (total_cost / units).round(2, BigDecimal::ROUND_HALF_UP)
      end

      {product: {id: product.id}, ordln_sku: sku_number(row), ordln_hts: text_value(row[9]), ordln_ordered_qty: units, ordln_ppu: unit_price, ordln_country_of_origin: text_value(row[35])}
    end

    def importer
      @imp ||= Company.importers.where(system_code: "CQ").first
      raise "No importer found with System Code 'CQ'." unless @imp

      @imp
    end

    def order_number row
      text_value(row[1]).strip
    end

    def part_number row
      text_value(row[36]).strip
    end

    def sku_number row
      text_value(row[6]).strip
    end

    def cq_part_number row
      # This is part number, but in order for CQ to make a unique number, they prepend a factory
      # code to the front of this value.  Which we don't necessarily get.
      text_value(row[7]).strip
    end

    def missing_products_builder
      @missing_products_builder ||= XlsxBuilder.new
    end

    def orders_missing_products_builder
      @orders_missing_products_builder ||= XlsxBuilder.new
    end

    def order_missing_products_only_errors_builder
      @order_missing_products_only_errors_builder ||= XlsxBuilder.new
    end

    def cdefs
      @cdefs ||= self.class.prep_custom_definitions [:prod_short_description, :prod_part_number]
    end

end; end; end; end