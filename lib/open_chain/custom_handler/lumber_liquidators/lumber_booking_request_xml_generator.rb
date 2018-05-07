require 'open_chain/xml_builder'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberBookingRequestXmlGenerator
  extend OpenChain::XmlBuilder

  def self.generate_xml shipment
    doc, elem_root = build_xml_document('ShippingOrderMessage')
    add_transaction_info_element elem_root, shipment
    add_shipping_order_element elem_root, shipment
    doc
  end

  class << self
    private
      def add_transaction_info_element elem_root, shipment
        elem_transaction_info = add_element(elem_root, 'TransactionInfo')
        add_element(elem_transaction_info, 'MessageSender', 'ACSVFILLQ')
        add_element(elem_transaction_info, 'MessageRecipient', 'ACSVFILLQ')
        current_date = ActiveSupport::TimeZone['UTC'].now
        add_element(elem_transaction_info, 'MessageID', current_date.strftime('%Y%m%d%H%M%S%L'))
        add_element(elem_transaction_info, 'Created', current_date.strftime('%Y-%m-%dT%H:%M:%S.%L'))
        add_element(elem_transaction_info, 'FileName', "Lumber_#{shipment.reference}.xml")
        add_element(elem_transaction_info, 'MessageOriginator', 'ACSVFILLQ')
        nil
      end

      def add_shipping_order_element root, shipment
        elem_shipping_order = add_element(root, 'ShippingOrder')
        elem_shipping_order.attributes['ShippingOrderNumber'] = shipment.reference
        add_element(elem_shipping_order, 'Purpose', 'Create')
        add_element(elem_shipping_order, 'ShippingOrderNumber', shipment.reference)
        add_element(elem_shipping_order, 'Status', 'Submitted')
        add_element(elem_shipping_order, 'CargoReadyDate', shipment.cargo_ready_date ? shipment.cargo_ready_date.strftime('%Y-%m-%dT%H:%M:%S.%L') : nil)
        add_element(elem_shipping_order, 'CommercialInvoiceNumber', 'N/A')
        first_booking_line = shipment.booking_lines.first
        add_port_of_loading_element elem_shipping_order, first_booking_line
        add_element(elem_shipping_order, 'LoadType', shipment.booking_shipment_type)
        add_element(elem_shipping_order, 'TransportationMode', shipment.booking_mode)
        add_element(elem_shipping_order, 'Division', 'LLIQ')
        shipment.booking_lines.each do |line|
          add_item_element elem_shipping_order, line
        end
        requested_equipment_breakdown = shipment.get_requested_equipment_pieces
        requested_equipment_breakdown.each do |requested_equipment_arr|
          add_equipment_element elem_shipping_order, requested_equipment_arr
        end
        add_party_info_element elem_shipping_order, 'Supplier', shipment.vendor, include_address:false
        add_party_info_element elem_shipping_order, 'Factory', shipment.ship_from, use_id_as_code: true
        if first_booking_line && first_booking_line.order_line
          add_party_info_element elem_shipping_order, 'ShipTo', first_booking_line.order_line.ship_to
        end
        if shipment.booking_requested_by
          add_element(elem_shipping_order, 'UserDefinedReferenceField1', shipment.booking_requested_by.full_name)
        end
        nil
      end

      def add_port_of_loading_element elem_shipping_order, booking_line
        if booking_line && booking_line.order && booking_line.order.fob_point
          elem_port_of_loading = add_element(elem_shipping_order, 'PortOfLoading')
          elem_city_code = add_element(elem_port_of_loading, 'CityCode', booking_line.order.fob_point)
          elem_city_code.attributes['Qualifier'] = 'UN'
        end
        nil
      end

      def add_item_element elem_shipping_order, booking_line
        elem_item = add_element(elem_shipping_order, 'Item')
        add_element(elem_item, 'Division', 'LLIQ')
        if booking_line.order
          add_element(elem_item, 'PurchaseOrderNumber', booking_line.order.order_number)
        end
        if booking_line.product
          # Strip zero-padding from the item number.  Allport's system can't handle it.
          add_element(elem_item, 'ItemNumber', booking_line.product.unique_identifier.sub(/^0+/, ""))
          add_element(elem_item, 'CommodityDescription', booking_line.product.name)
        end
        elem_total_gross_weight = add_element(elem_item, 'TotalGrossWeight', booking_line.gross_kgs)
        elem_total_gross_weight.attributes['Unit'] = 'KG'
        add_element(elem_item, 'TotalCubicMeters', booking_line.cbms)
        elem_quantity = add_element(elem_item, 'Quantity', booking_line.quantity)
        elem_quantity.attributes['ANSICode'] = get_gtn_quantity_uom booking_line
        if booking_line.order_line
          add_element(elem_item, 'POLineNumber', booking_line.order_line.line_number)
        end
        nil
      end

      def get_gtn_quantity_uom booking_line
        uom = nil
        if booking_line.order_line
          uom = DataCrossReference.where(cross_reference_type:DataCrossReference::LL_GTN_QUANTITY_UOM, key:booking_line.order_line.unit_of_measure).pluck(:value).first
        end
        uom
      end

      def add_equipment_element elem_shipping_order, requested_equipment
        elem_equipment = add_element(elem_shipping_order, 'Equipment')
        add_element(elem_equipment, 'Code', get_gtn_equipment_type(requested_equipment[1]))
        add_element(elem_equipment, 'Type', requested_equipment[1])
        add_element(elem_equipment, 'Quantity', requested_equipment[0])
        nil
      end

      def get_gtn_equipment_type equipment_type
        DataCrossReference.where(cross_reference_type:DataCrossReference::LL_GTN_EQUIPMENT_TYPE, key:equipment_type).pluck(:value).first
      end

      def add_party_info_element elem_shipping_order, party_type, addr, include_address:true, use_id_as_code:false
        if addr
          elem_party_info = add_element(elem_shipping_order, 'PartyInfo')
          add_element(elem_party_info, 'Type', party_type)
          # Missing system code causes explosions on Allport's side despite the value not actually being needed for all.
          add_element(elem_party_info, 'Code', use_id_as_code ? addr.id : addr.system_code)
          add_element(elem_party_info, 'Name', addr.name)
          if include_address
            add_element(elem_party_info, 'AddressLine1', addr.line_1)
            add_element(elem_party_info, 'AddressLine2', addr.line_2)
            add_element(elem_party_info, 'AddressLine3', addr.line_3)
            add_element(elem_party_info, 'CityName', addr.city)
            add_element(elem_party_info, 'State', addr.state)
            add_element(elem_party_info, 'PostalCode', addr.postal_code)
            add_element(elem_party_info, 'CountryName', addr.country ? addr.country.name : nil)
          end
        end
        nil
      end
  end

end;end;end;end