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
    @cdefs = self.class.prep_custom_definitions [:prod_sku_number]
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
        missing_products_spreadsheet, orders_spreadsheet = create_spreadsheets result.orders_missing_products, result.header_row
      end

      if missing_products_spreadsheet
        base_file_name = File.basename(custom_file.attached_file_name)
        name = File.basename(base_file_name, ".*")

        Tempfile.open([name, ".xls"]) do |missing_products|
          Attachment.add_original_filename_method missing_products, "#{name} - Missing Products.xls"
          missing_products_spreadsheet.write missing_products

          Tempfile.open(["#{name}_orders", ".xls"]) do |orders|
            Attachment.add_original_filename_method orders, "#{name} - Orders.xls"
            orders_spreadsheet.write orders

            body = "Attached are the product lines that were missing from VFI Track.  Please fill out the #{missing_products.original_filename} file with all the necessary information and load the data into VFI Track, then reprocess the attached #{orders.original_filename} PO file to load the POs that were missing products into the system."
            OpenMailer.send_simple_html(user.email, "CQ Origin PO Report Result", body, [missing_products, orders]).deliver!
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
        next if row[1].blank? || row[6].blank?

        ord_num = order_number(row)
        row[1] = ord_num

        if current_order_lines.length > 0 && order_number(current_order_lines[0]) != ord_num
          if current_order_missing_product
            orders_missing_products.push *current_order_lines
          end

          current_order_lines.clear
          current_order_missing_product = false
        end

        current_order_lines << row

        # Find the product for this line.
        product = find_product text_value(row[6]).strip
        if product
          order_number = text_value(row[1]).strip
          order = orders[order_number]
          if order.nil?
            order = build_order_header row
            orders[order_number] = order
          end
          order[:order_lines_attributes] << build_order_line(row, product)
          row[row.size + 1] = false
        else
          current_order_missing_product = true
          missing_product_count += 1
          # Add an indicator to the row, which we'll strip off later to show that this particular line
          # is missing a product (we want to highlight these rows in the file we send back out)
          row[row.size + 1] = true
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
        missing_products << text_value(row[6]) if missing_product?(row) && !text_value(row[6]).blank?
      end

      product_wb, sheet = XlsMaker.create_workbook_and_sheet 'Missing Products', ["AAP SKU (Item Number)", "Part Number", "CQ Line Code", "CQ SKU", "Merchandise Group Description", 
        "Merchandise Department Description", "Merchandise Class Description", "Merchandise Sub-Class Description", "Item Description", "US HTS Code", "US Duty", 
        "CAN HS Code", "CAN Duty", "Freight Cost", "Piece Per Set", "Comments"]

      missing_products.to_a.each_with_index do |part_number, i|
        XlsMaker.add_body_row sheet, (i+1), [part_number, nil, nil, nil]
      end

      order_wb, sheet = XlsMaker.create_workbook_and_sheet "Orders Missing Products", header_row
      missing_product_format = Spreadsheet::Format.new pattern_fg_color: :yellow, pattern: 1
      missing_product_format_dates = Spreadsheet::Format.new pattern_fg_color: :yellow, pattern: 1, number_format: 'YYYY-MM-DD'
      date_indexes = [14, 15, 17, 18, 19]
      orders_missing_products.each_with_index do |row, i|
        if missing_product?(row)
          XlsMaker.add_body_row sheet, (i+1), row[0..-2], [], false, format: missing_product_format
          # When we set the format of the row, we then change the format for dates (to numeric)
          # I don't know a way to "merge" formats intelligently, so I'm just going to update the format for
          # the date columns to use the date format w/ yellow background
          row = sheet.row(i+1)
          date_indexes.each {|idx| row.set_format idx, missing_product_format_dates}
        else
          XlsMaker.add_body_row sheet, (i+1), row[0..-2], [], true
        end
      end

      [product_wb, order_wb]
    end

    def missing_product? row
      # If the last value in the row is true, it means it's missing the product line
      row[-1] === true
    end

    def find_product sku
      Product.where(importer_id: importer).joins(:custom_values).where(custom_values: {custom_definition_id: @cdefs[:prod_sku_number].id, string_value: sku}).first
    end

    def build_order_header row
      {ord_ord_num: "#{importer.system_code}-#{text_value(row[1]).strip}", ord_cust_ord_no: text_value(row[1]), ord_imp_id: importer.id, ord_ord_date: date_value(row[14]), order_lines_attributes: []}
    end

    def build_order_line row, product
      {product: {id: product.id}, ordln_sku: text_value(row[6]), ordln_hts: text_value(row[9]), ordln_ordered_qty: decimal_value(row[10], decimal_places: 2)}
    end

    def importer
      @imp ||= Company.importers.where(system_code: "CQ").first
      raise "No importer found with System Code 'CQ'." unless @imp

      @imp
    end

    def order_number row
      text_value(row[1]).strip
    end

end; end; end; end