require 'open_chain/xl_client'
require 'open_chain/custom_handler/custom_file_csv_excel_parser'

module OpenChain; module CustomHandler; module GenericShipmentWorksheetParserSupport
  extend ActiveSupport::Concern
  include OpenChain::CustomHandler::CustomFileCsvExcelParser

  module ClassMethods
    def process_attachment(shipment, attachment, user, opts = {})
      # Just swallow the opts if the initializer doesn't have any parameters
      if self.instance_method(:initialize).arity != 0
        self.new(opts).process_attachment(shipment, attachment, user)
      else
        self.new.process_attachment(shipment, attachment, user)
      end
      
    end
  end

  def process_attachment(shipment, attachment, user) 
    process_rows(shipment, foreach(attachment), user)
  end

  ##
  # A hash pointing to where attributes are in the spreadsheet.
  # Subclasses should override this method (or call super and modify the result) rather than hard-coding rows and columns.
  #
  # @return [Hash] the layout
  def file_layout
    {
      marks_column: 0,
      description_column: 1,
      po_column: 2,
      style_no_column: 3,
      sku_column:4,
      hts_column: 5,
      carton_qty_column: 6,
      quantity_column: 7,
      unit_type_column: 8,
      cbms_column: 9,
      gross_kgs_column: 10,
      total_column: 5,
      header_row: 34,
      port_of_receipt: {
        row: 28,
        column: 5
      },
      mode: {
        row: 28,
        column: 7
      },
      terms: {
        row: 30,
        column: 7
      },
      ready_date: {
        row: 28,
        column: 10
      },
      shipment_type: {
        row: 30,
        column:10
      }
    }
  end


  ##
  # Makes sure the user can edit the shipment, then reads the row data and adds lines
  # @param [Shipment] shipment
  # @param [Array<Array>] rows
  # @param [User] user
  def process_rows(shipment, rows, user)
    raise "You do not have permission to edit this shipment." unless shipment.can_edit?(user)
    Lock.with_lock_retry(shipment) do
      add_header_data shipment, rows
      line_number = max_line_number(shipment)
      shipment_lines(rows) do |row|
        add_line_data shipment, row, (line_number += 1)
      end
      shipment.save!
      # This is techincally done from the front-end (.ie files are processed as part of the request cycle).
      # So make sure the snapshot is done asyncronously.
      shipment.create_async_snapshot user
    end
  end  

  def shipment_lines(rows) 
    cursor = file_layout[:header_row]
    while (cursor+=1) < rows.size
      row = rows[cursor]
      yield row if valid_line?(row)
    end
  end

  def value_from_named_location(name, rows)
    rows[file_layout[name][:row]][file_layout[name][:column]]
  end

  def valid_line?(row)
    numeric_fields = [:quantity_column, :carton_qty_column, :cbms_column, :gross_kgs_column]
    text_fields = [:po_column, :sku_column, :style_no_column]

    is_not_total(row) && (
      text_fields.any? { |field| row[file_layout[field]].present? } ||
      numeric_fields.any? { |field| is_number? row[file_layout[field]] } )
  end

  def is_number?(value)
    value.present? && (value.is_a?(Numeric) || value.match(/\A[-+]?[0-9]*\.?[0-9]+\Z/))
  end

  def is_not_total(row)
    !(row[file_layout[:total_column]] && row[file_layout[:total_column]].to_s.match(/total/i))
  end

  def find_order_line(shipment, po, sku, error_if_not_found: false)
    ord = find_order(shipment, po, error_if_not_found: error_if_not_found)
    ol = ord.order_lines.find_by_sku(sku)
    raise "SKU #{sku} not found in order #{po} (ID: #{ord.id})." if error_if_not_found && ol.nil?
    ol
  end

  def find_product(shipment, style, error_if_not_found: false)
    @product_cache ||= {}

    prod = @product_cache[style]
    if prod.nil?
      prod = Product.where(unique_identifier: "#{shipment.importer.system_code}-#{style}").first
      @product_cache[style] = prod
    end

    prod
  end

  def find_order(shipment, po, error_if_not_found: false)
    @order_cache ||= Hash.new
    ord = @order_cache[po]
    if ord.nil?
      ord = Order.where(customer_order_number: po, importer_id: shipment.importer_id).includes(:order_lines => [:product]).first
      raise "Order Number #{po} not found." if error_if_not_found && ord.nil?
      @order_cache[po] = ord
    end

    ord
  end

end; end; end