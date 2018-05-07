require 'open_chain/xml_builder'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_helper'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberIsfShipmentXmlGenerator
  extend OpenChain::XmlBuilder

  def self.generate_xml shipment
    doc, elem_root = build_xml_document('IsfEdiUpload')
    elem_root.add_namespace 'xsi', 'http://www.w3.org/2001/XMLSchema-instance'
    elem_root.add_namespace 'isf', 'http://isf.kewill.com/ws/upload/'
    add_element(elem_root, 'CUSTOMER_ACCT_CD', 'VAND0323')
    add_element(elem_root, 'USER_NAME', 'VAND0323')
    add_element(elem_root, 'PASSWORD', 'k3w1ll')
    current_date = ActiveSupport::TimeZone['UTC'].now
    add_element(elem_root, 'DATE_CREATED', format_date(current_date))
    add_element(elem_root, 'EDI_TXN_IDENTIFIER', '168820')
    add_element(elem_root, 'ACTION_CD', get_action_code(shipment))
    add_element(elem_root, 'ACTION_REASON_CD', "CT")
    add_element(elem_root, 'DOCUMENT_TYPE_CD', 'BL')
    add_element(elem_root, 'IMPORTER_ACCT_CD', 'LUMBER')
    add_element(elem_root, 'OWNER_ACCT_CD', 'VAND0323')
    add_element(elem_root, 'SHIPMENT_TYPE', '01')
    add_element(elem_root, 'MOT_CD', '11')
    add_element(elem_root, "VOAYGE_NBR", shipment.voyage)
    add_element(elem_root, 'EST_SAIL_DATE', format_date(shipment.est_departure_date))
    add_element(elem_root, 'SCAC_CD', get_scac_code(shipment.master_bill_of_lading))
    # The Shipment reference number is sent into the PO Number field, as this field gets pulled over onto the entry into the customer references field.
    # There it is used so the shipment docs sent by the forwarder can be matched to the entry and automatically attached by the lumber entry pack change comparator.
    add_element(elem_root, 'PO_NBR', shipment.reference)
    add_element(elem_root, 'BOOKING_NBR', shipment.shipment_lines.first.try(:order_lines).first.try(:order).try(:order_number))
    if shipment.master_bill_of_lading
      add_edi_bill_lading_element elem_root, shipment.master_bill_of_lading
    end

    importer_address = get_company_address(shipment.importer, "ISF Importer")
    add_party_edi_entity_element elem_root, 'IM', importer_address, entity_id: importer_address.try(:system_code)
    add_party_edi_entity_element elem_root, 'SE', shipment.seller_address
    add_party_edi_entity_element elem_root, 'BY', shipment.buyer_address
    add_party_edi_entity_element elem_root, 'ST', shipment.ship_to_address
    consignee_address = get_company_address(shipment.consignee, "ISF Consignee")
    add_party_edi_entity_element elem_root, 'CN', consignee_address, entity_id: consignee_address.try(:system_code)
    add_party_edi_entity_element elem_root, 'CS', shipment.consolidator_address
    add_party_edi_entity_element elem_root, 'LG', shipment.container_stuffing_address
    add_party_edi_entity_element elem_root, 'MF', shipment.ship_from, entity_id: "1"

    shipment.shipment_lines.each do |shipment_line|
      # Shipment lines rarely, if ever, connect to more than one order line, but it is technically possible.
      shipment_line.order_lines.each do |order_line|
        add_edi_line_element elem_root, order_line, shipment.country_origin.try(:iso_code), "1"
      end
    end

    doc
  end

  class << self
    private
      def format_date d
        d ? d.strftime('%Y-%m-%dT%H:%M:%S') : nil
      end

      def get_action_code shipment
        sync_count = shipment.sync_records.where(trading_partner: 'ISF').length
        sync_count > 0 ? 'R' : 'A'
      end

      def get_scac_code bill_of_lading
        bill_of_lading ? bill_of_lading[0, 4] : nil
      end

      def add_edi_bill_lading_element elem_root, bill_of_lading
        elem_edi_bill_lading = add_element(elem_root, 'EdiBillLading')
        add_element(elem_edi_bill_lading, 'MASTER_BILL_NBR', get_bill_of_lading_number(bill_of_lading))
        add_element(elem_edi_bill_lading, 'MASTER_BILL_SCAC_CD', get_scac_code(bill_of_lading))
        nil
      end

      def get_bill_of_lading_number bill_of_lading
        bill_of_lading ? bill_of_lading[4, bill_of_lading.length] : nil
      end

      # Returns a dummy hard-coded address used for both importer and consignee.
      def get_company_address company, address_type
        if company
          company.addresses.where(address_type: address_type).first
        else
          nil
        end
      end

      def add_party_edi_entity_element elem_root, party_type, addr, entity_id: nil, entity_id_type_cd: "EI"
        if addr
          elem_party_info = add_element(elem_root, 'EdiEntity')
          add_element(elem_party_info, 'ENTITY_TYPE_CD', party_type)
          if !entity_id.blank?
            add_element(elem_party_info, 'ENTITY_ID', entity_id)
            add_element(elem_party_info, 'ENTITY_ID_TYPE_CD', entity_id_type_cd)
          end
          add_element(elem_party_info, 'NAME', addr.name)
          add_element(elem_party_info, 'ADDRESS_1', addr.line_1)
          add_element(elem_party_info, 'ADDRESS_2', addr.line_2)
          add_element(elem_party_info, 'ADDRESS_3', addr.line_3)
          add_element(elem_party_info, 'CITY', addr.city)
          add_element(elem_party_info, 'COUNTRY_SUBENTITY_CD', addr.state)
          add_element(elem_party_info, 'POSTAL_CD', addr.postal_code)
          add_element(elem_party_info, 'COUNTRY_CD', addr.country ? addr.country.iso_code : nil)
        end
        nil
      end

      def add_edi_line_element elem_root, order_line, country_origin, manufacturer_id
        elem_item = add_element(elem_root, 'EdiLine')
        add_element(elem_item, "MFG_SUPPLIER_CD", manufacturer_id)
        add_element(elem_item, 'ORIGIN_COUNTRY_CD', country_origin)
        add_element(elem_item, 'PO_NBR', order_line.order.order_number)
        if order_line.product
          add_element(elem_item, 'PART_CD', order_line.product.unique_identifier.sub(/^0+/, ""))
        end
        nil
      end
  end

end;end;end;end