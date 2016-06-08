require 'open_chain/custom_handler/generic_shipment_worksheet_parser_support'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; class GenericShipmentManifestParser
  include OpenChain::CustomHandler::GenericShipmentWorksheetParserSupport
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def initialize opts = {}
    @cdefs = self.class.prep_custom_definitions [:prod_part_number]
    @manufacturer_address_id = opts[:manufacturer_address_id]
  end

  def file_layout
    {
      marks_column: 0,
      description_column: 1,
      po_column: 2,
      style_no_column: 3,
      sku_column:4,
      carton_qty_column: 5,
      quantity_column: 6,
      unit_type_column: 7,
      cbms_column: 8,
      gross_kgs_column: 9,
      container_column: 11,
      seal_column: 12,
      total_column: 5,
      header_row: 34,
      port_of_receipt: {
        row: 28,
        column: 5
      },
      mode: {
        row: 28,
        column: 8
      },
      terms: {
        row: 30,
        column: 8
      },
      ready_date: {
        row: 28,
        column: 11
      },
      shipment_type: {
        row: 30,
        column:11
      }
    }
  end

  def max_line_number shipment
    shipment.shipment_lines.maximum(:line_number) || 0
  end

  def add_header_data(shipment, rows)
    shipment.receipt_location = value_from_named_location :port_of_receipt, rows
    shipment.cargo_ready_date = value_from_named_location :ready_date, rows
    shipment.freight_terms = value_from_named_location :terms, rows
    shipment.shipment_type = value_from_named_location :shipment_type, rows
    shipment.lcl = (shipment.shipment_type == 'CFS/CFS')
    mode = value_from_named_location :mode, rows
    if mode.to_s.upcase == "OCEAN"
      # Careful w/ these values....they need to match the values the front-end is 
      # displaying w/ it's dropdowns.
      shipment.mode = case shipment.shipment_type.to_s.upcase
                      when "CY/CY", "CY/CFS"
                       "Ocean - FCL"
                      when "CFS/CY", "CFS/CFS"
                        "Ocean - LCL"
                      else
                        nil
                      end
    end

    marks_and_numbers = []
    shipment_lines(rows) do |row|
      man = row[file_layout[:marks_column]]
      marks_and_numbers << man unless man.blank?
    end

    man = marks_and_numbers.join " "
    if !man.blank? && shipment.marks_and_numbers != man
      shipment.marks_and_numbers = (shipment.marks_and_numbers ? (shipment.marks_and_numbers + " ") : "") + man
    end

    shipment
  end

  def add_line_data(shipment, row, line_number)
    # Regardless of whether a po and sku/style are present, we're going to make the container if the data is present
    container_number = text_value(row[file_layout[:container_column]]).to_s.upcase
    container = shipment.containers.find {|c| c.container_number.to_s.upcase == container_number }
    if container.nil? && !container_number.blank?
      container = shipment.containers.build container_number: container_number, seal_number: text_value(row[file_layout[:seal_column]]).to_s.upcase
    end

    po = text_value(row[file_layout[:po_column]]).to_s.strip
    style = text_value(row[file_layout[:style_no_column]]).to_s.strip
    sku = text_value(row[file_layout[:sku_column]]).to_s.strip

    # A po and sku/style must be present before we bother trying to process this line
    return if po.blank? || (style.blank? && sku.blank?)

    order = find_order(shipment, po)
    return if order.nil?

    # Use the sku as the first lookup value if given as that should be the more precise.
    order_line = order.order_lines.find {|ol| ol.sku == sku } unless sku.blank?

    # Fall back to the style..matching on the product's part number since the unique_identifier field will have the importer system code
    # in it on the main vfitrack instance.
    order_line = order.order_lines.find do |ol|
      product = ol.product
      style == product.custom_value(@cdefs[:prod_part_number])
    end if order_line.nil? && !style.blank?

    return if order_line.blank?

    shipment_line = shipment.shipment_lines.build linked_order_line_id: order_line.id, product: order_line.product
    shipment_line.quantity = decimal_value row[file_layout[:quantity_column]]
    shipment_line.container = container
    shipment_line.cbms = decimal_value row[file_layout[:cbms_column]]
    shipment_line.gross_kgs = decimal_value row[file_layout[:gross_kgs_column]]
    shipment_line.carton_qty = decimal_value row[file_layout[:carton_qty_column]]
    shipment_line.manufacturer_address_id = @manufacturer_address_id if @manufacturer_address_id.to_i != 0

    nil
  end

end; end; end