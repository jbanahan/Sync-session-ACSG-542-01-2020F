require 'open_chain/xl_client'

module OpenChain; module CustomHandler; class GenericBookingParser

  ##
  # @param [Shipment] shipment
  # @param [Attachment] attachment
  # @param [User] user
  def self.process_attachment(shipment, attachment, user)
    parse shipment, attachment.attached.path, user
  end

  ##
  # @param [Shipment] shipment
  # @param [String] path
  # @param [User] user
  def self.parse(shipment, path, user)
    self.new.run(shipment, OpenChain::XLClient.new(path), user)
  end

  ##
  # @param [Shipment] shipment
  # @param [XLClient] xl_client
  # @param [User] user
  def run(shipment, xl_client, user)
    process_rows shipment, xl_client.all_row_values, user
  end

  ##
  # Makes sure the user can edit the shipment, then reads the row data and adds lines
  # @param [Shipment] shipment
  # @param [Array<Array>] rows
  # @param [User] user
  def process_rows(shipment, rows, user)
    validate_user_and_process_rows shipment, rows, user
  end

  ##
  # Skips user permission check, reads rows and adds them to the shipment
  # @param [Shipment] shipment
  # @param [Array<Array>] rows
  def process_rows!(shipment, rows)
    process_row_data shipment, rows
    shipment.save!
  end

  private
  def validate_user_and_process_rows(shipment, rows, user)
    within_lock(shipment) do
      raise "You do not have permission to edit this shipment." unless shipment.can_edit?(user)
      process_rows! shipment, rows
    end
  end

  def process_row_data(shipment,rows)
    validate_rows rows
    add_rows_to_shipment shipment, rows
  end

  def add_rows_to_shipment(shipment, rows)
    add_metadata shipment, rows
    add_lines shipment, rows
  end

  def within_lock(shipment)
    Lock.acquire("Shipment-#{shipment.id}") do
      Lock.with_lock_retry shipment do
        return yield
      end
    end
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
        header_row: 34,
        port_of_receipt: {
            row: 28,
            column: 5
        },
        port_of_lading: {
            row: 30,
            column: 5
        },
        destination_port: {
            row: 32,
            column:1
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
  # Validation lives here. Does not return a value; throw an exception if the sheet is invalid
  # @param [Array<Array>] rows
  def validate_rows(rows)
    #   No validation in the generic parser
  end

  ##
  # Gets shipment header info from the rows
  # @param [Shipment] shipment
  # @param [Array<Array>] rows
  def add_metadata(shipment, rows)
    port_receipt_name = value_from_named_location :port_of_receipt, rows
    shipment.first_port_receipt = Port.find_by_name port_receipt_name
    shipment.receipt_location = port_receipt_name
    shipment.cargo_ready_date = value_from_named_location :ready_date, rows

    shipment.lading_port = Port.find_by_name value_from_named_location :port_of_lading, rows
    shipment.freight_terms = value_from_named_location :terms, rows
    shipment.shipment_type = value_from_named_location :shipment_type, rows
    shipment.booking_shipment_type = shipment.shipment_type
    shipment.lcl = (shipment.shipment_type == 'CFS/CFS')
    shipment.mode = value_from_named_location :mode, rows

    destination_port_name = value_from_named_location :destination_port, rows
    shipment.unlading_port = Port.find_by_name destination_port_name
    shipment.destination_port = shipment.unlading_port

  end

  def value_from_named_location(name, rows)
    rows[file_layout[name][:row]][file_layout[name][:column]]
  end

  ##
  # Creates booking lines from row data
  # @param [Shipment] shipment
  # @param [Array<Array>] rows
  def add_lines(shipment, rows)
    max_line_number = max_line_number(shipment)
    marks = " "

    cursor = file_layout[:header_row]+1
    while cursor < rows.size
      row = rows[cursor]
      cursor += 1
      marks += row[file_layout[:marks_column]] + " " if row[file_layout[:marks_column]].present?
      if row[file_layout[:sku_column]].present? && (row[file_layout[:sku_column]].is_a?(Numeric) || row[file_layout[:sku_column]].match(/\d/))
        max_line_number += 1
        add_line shipment, row, max_line_number
        next
      end
    end
    shipment.marks_and_numbers ||= ""
    shipment.marks_and_numbers += marks
  end

  ##
  # The highest line number of all a shipment's booking lines
  # @param [Shipment] shipment
  # @return [Numeric]
  def max_line_number(shipment)
    shipment.booking_lines.maximum(:line_number) || 0
  end

  ##
  # Builds a booking_line for the +shipment+ from the +row+ data with the given +line_number+
  # @param [Shipment] shipment
  # @param [Array] row
  # @param [Numeric] line_number
  def add_line(shipment, row, line_number)
    po = row[file_layout[:po_column]].round.to_s
    sku = row[file_layout[:sku_column]].round.to_s
    quantity = clean_number(row[file_layout[:quantity_column]])
    cbms = row[file_layout[:cbms_column]]
    gross_kgs = row[file_layout[:gross_kgs_column]]
    carton_quantity = row[file_layout[:carton_qty_column]]

    ol = find_order_line shipment, po, sku
    shipment.booking_lines.build(
        product: ol.product,
        quantity: quantity,
        line_number: line_number,
        linked_order_line_id: ol.id,
        order_line_id: ol.id,
        order_id: ol.order.id,
        cbms: cbms,
        gross_kgs: gross_kgs,
        carton_qty: carton_quantity
    )
  end

  def clean_number num
    return nil if num.blank?
    num.to_s.gsub(',','').strip
  end

  def convert_number(num, conversion)
    n = clean_number num
    return nil if n.nil?
    BigDecimal(n) * conversion
  end

  def find_order_line(shipment, po, sku)
    @order_cache ||= Hash.new
    ord = @order_cache[po]
    if ord.nil?
      ord = Order.where(customer_order_number: po, importer_id: shipment.importer_id).includes(:order_lines).first
      raise "Order Number #{po} not found." unless ord
      @order_cache[po] = ord
    end
    ol = ord.order_lines.find_by_sku(sku)
    raise "SKU #{sku} not found in order #{po} (ID: #{ord.id})." unless ol
    ol
  end

  def header_row_index(rows, name)
    rows.index { |r| r.size > 1 && r[1]==name }
  end
end; end; end