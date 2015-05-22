require 'open_chain/xl_client'

module OpenChain; module CustomHandler; class GenericPackManifestParser
  MARKS_COLUMN = 0
  DESCRIPTION_COLUMN = 1
  PO_COLUMN = 2
  STYLE_NO_COLUMN = 3
  SKU_COLUMN = 4
  HTS_COLUMN = 5
  CARTON_QTY_COLUMN = 6
  QUANTITY_COLUMN = 7
  UNIT_TYPE_COLUMN = 8
  CBMS_COLUMN = 9
  GROSS_KGS_COLUMN = 10

  PORT_OF_RECEIPT_COLUMN = 5
  PORT_OF_LADING_COLUMN = 5
  MODE_COLUMN = 7
  TERMS_COLUMN = 7
  READY_DATE_COLUMN = 10
  SHIPMENT_TYPE_COLUMN = 10

  FIRST_METADATA_ROW = 28
  SECOND_METADATA_ROW = 30
  HEADER_ROW = 34

  DESTINATION_PORT_ROW = 32
  DESTINATION_PORT_COLUMN = 1

  def self.process_attachment shipment, attachment, user
    parse shipment, attachment.attached.path, user
  end

  def self.parse shipment, path, user
    self.new.run(shipment,OpenChain::XLClient.new(path),user)
  end

  def run shipment, xl_client, user
    process_rows shipment, xl_client.all_row_values, user
  end

  def process_rows shipment, rows, user
    validate_user_and_process_rows shipment, rows, user
  end

  def process_rows!(shipment, rows)
    process_row_data shipment, rows
    shipment.save!
  end

  private
  def validate_user_and_process_rows(shipment, rows, user)
    ActiveRecord::Base.transaction do
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

  def validate_rows rows
  #   No validation in the generic parser
  end

  def add_metadata(shipment, rows)
    row = rows[FIRST_METADATA_ROW]
    port_receipt_name = row[PORT_OF_RECEIPT_COLUMN]
    shipment.first_port_receipt = Port.find_by_name port_receipt_name
    shipment.receipt_location = port_receipt_name
    shipment.cargo_ready_date = row[READY_DATE_COLUMN]

    row = rows[SECOND_METADATA_ROW]
    shipment.lading_port = Port.find_by_name row[PORT_OF_LADING_COLUMN]
    shipment.freight_terms = row[TERMS_COLUMN]
    shipment.shipment_type = row[SHIPMENT_TYPE_COLUMN]
    shipment.booking_shipment_type = shipment.shipment_type
    shipment.lcl = (shipment.shipment_type == 'CFS/CFS')

    destination_port_name = rows[DESTINATION_PORT_ROW][DESTINATION_PORT_COLUMN]
    shipment.unlading_port = Port.find_by_name destination_port_name
    shipment.destination_port = shipment.unlading_port

  end

  def add_lines shipment, rows
    max_line_number = max_line_number(shipment)
    marks = " "

    cursor = HEADER_ROW+1
    while cursor < rows.size
      row = rows[cursor]
      cursor += 1
      marks += row[MARKS_COLUMN] + " " if row[MARKS_COLUMN].present?
      if row[SKU_COLUMN].present? && (row[SKU_COLUMN].is_a?(Numeric) || row[SKU_COLUMN].match(/\d/) )
        max_line_number += 1
        add_line shipment, row, max_line_number
        next
      end
    end
    shipment.marks_and_numbers ||= ""
    shipment.marks_and_numbers += marks
  end

  def max_line_number(shipment)
    shipment.booking_lines.maximum(:line_number) || 0
  end

  def add_line shipment, row, line_number
    po = row[PO_COLUMN].round.to_s
    sku = row[SKU_COLUMN].round.to_s
    quantity = clean_number(row[QUANTITY_COLUMN])
    cbms = row[CBMS_COLUMN]
    gross_kgs = row[GROSS_KGS_COLUMN]
    carton_quantity = row[CARTON_QTY_COLUMN]

    ol = find_order_line shipment, po, sku
    shipment.booking_lines.build(
        product:ol.product,
        quantity:quantity,
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

  def convert_number num, conversion
    n = clean_number num
    return nil if n.nil?
    BigDecimal(n) * conversion
  end

  def find_order_line shipment, po, sku
    @order_cache ||= Hash.new
    ord = @order_cache[po]
    if ord.nil?
      ord = Order.where(customer_order_number:po,importer_id:shipment.importer_id).includes(:order_lines).first
      raise "Order Number #{po} not found." unless ord
      @order_cache[po] = ord
    end
    ol = ord.order_lines.find {|ln| ln.sku == sku}
    raise "SKU #{sku} not found in order #{po} (ID: #{ord.id})." unless ol
    ol
  end

  def header_row_index rows, name
    rows.index {|r| r.size > 1 && r[1]==name}
  end
end; end; end