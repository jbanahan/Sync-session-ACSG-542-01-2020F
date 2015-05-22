require 'open_chain/xl_client'

module OpenChain; module CustomHandler; class GenericPackManifestParser
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
    shipment.with_lock do
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
    Lock.acquire("Shipment-#{shipment.id}", temp_lock:true) do
      return yield
    end
  end

  def validate_rows rows
  #   No validation in the generic parser
  end

  def add_metadata(shipment, rows)
    port_receipt_name = rows[file_layout[:port_of_receipt][:row]][file_layout[:port_of_receipt][:column]]
    shipment.first_port_receipt = Port.find_by_name port_receipt_name
    shipment.receipt_location = port_receipt_name
    shipment.cargo_ready_date = rows[file_layout[:ready_date][:row]][file_layout[:ready_date][:column]]

    shipment.lading_port = Port.find_by_name rows[file_layout[:port_of_lading][:row]][file_layout[:port_of_lading][:column]]
    shipment.freight_terms = rows[file_layout[:terms][:row]][file_layout[:terms][:column]]
    shipment.shipment_type = rows[file_layout[:shipment_type][:row]][file_layout[:shipment_type][:column]]
    shipment.booking_shipment_type = shipment.shipment_type
    shipment.lcl = (shipment.shipment_type == 'CFS/CFS')

    destination_port_name = rows[file_layout[:destination_port][:row]][file_layout[:destination_port][:column]]
    shipment.unlading_port = Port.find_by_name destination_port_name
    shipment.destination_port = shipment.unlading_port

  end

  def add_lines shipment, rows
    max_line_number = max_line_number(shipment)
    marks = " "

    cursor = file_layout[:header_row]+1
    while cursor < rows.size
      row = rows[cursor]
      cursor += 1
      marks += row[file_layout[:marks_column]] + " " if row[file_layout[:marks_column]].present?
      if row[file_layout[:sku_column]].present? && (row[file_layout[:sku_column]].is_a?(Numeric) || row[file_layout[:sku_column]].match(/\d/) )
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
    po = row[file_layout[:po_column]].round.to_s
    sku = row[file_layout[:sku_column]].round.to_s
    quantity = clean_number(row[file_layout[:quantity_column]])
    cbms = row[file_layout[:cbms_column]]
    gross_kgs = row[file_layout[:gross_kgs_column]]
    carton_quantity = row[file_layout[:carton_qty_column]]

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