require 'open_chain/custom_handler/generic_shipment_worksheet_parser_support'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; class GenericBookingParser
  include OpenChain::CustomHandler::GenericShipmentWorksheetParserSupport
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def initialize opts = {}
    @check_orders = opts[:check_orders]
  end

  def parser_type
    :bookings
  end

  ##
  # The highest line number of all a shipment's booking lines
  # @param [Shipment] shipment
  # @return [Numeric]
  def max_line_number shipment
    shipment.booking_lines.maximum(:line_number) || 0
  end

  ##
  # Gets shipment header info from the rows
  # @param [Shipment] shipment
  # @param [Array<Array>] rows
  def add_header_data(shipment, rows)
    shipment.receipt_location = value_from_named_location :port_of_receipt, rows
    shipment.cargo_ready_date = value_from_named_location :ready_date, rows
    shipment.freight_terms = value_from_named_location :terms, rows
    shipment.shipment_type = value_from_named_location :shipment_type, rows
    shipment.booking_shipment_type = shipment.shipment_type
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
      shipment.booking_mode = shipment.mode
    end

    marks_and_numbers = []
    shipment_lines(rows) do |row|
      man = row[file_layout[:marks_column]]
      marks_and_numbers << man unless man.blank?
    end

    shipment.marks_and_numbers = (shipment.marks_and_numbers ? (shipment.marks_and_numbers + " ") : "") + marks_and_numbers.join(" ") unless marks_and_numbers.blank?

    shipment
  end

  ##
  # Builds a booking_line for the +shipment+ from the +row+ data with the given +line_number+
  # @param [Shipment] shipment
  # @param [Array] row
  # @param [Numeric] line_number
  def add_line_data(shipment, row, line_number)
    po = text_value row[file_layout[:po_column]]

    # If there's no PO, we cannot match up lines.  Previously, this parser included some logic to pull the most recent
    # order line for an importer and SKU combination if there was no PO, but this was removed in Sep 2017.  Per JH,
    # that logic was "flat out wrong and bad."
    if !po.blank?
      order = find_order shipment, po, error_if_not_found: true
      if order
        sku = text_value row[file_layout[:sku_column]]
        style = text_value row[file_layout[:style_no_column]]

        if !sku.blank?
          order_line = order.order_lines.find_by_sku(sku)
        elsif !style.blank?
          # Fall back to the style, matching on the product's part number since the unique_identifier field will have
          # the importer system code in it on the main vfitrack instance.
          order_line = find_order_line_by_style order, style
        end

        if !order_line.blank?
          quantity = decimal_value row[file_layout[:quantity_column]]
          cbms = decimal_value row[file_layout[:cbms_column]]
          gross_kgs = decimal_value row[file_layout[:gross_kgs_column]]
          carton_quantity = decimal_value row[file_layout[:carton_qty_column]]
          shipment.booking_lines.build(
            quantity: quantity,
            line_number: line_number,
            order_line_id: order_line.id,
            cbms: cbms,
            gross_kgs: gross_kgs,
            carton_qty: carton_quantity
          )
        end
      end
    end
  end

end; end; end
