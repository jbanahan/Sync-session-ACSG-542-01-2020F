require 'open_chain/custom_handler/gt_nexus/generic_gtn_order_xml_parser'

module OpenChain; module CustomHandler; module Pvh; class PvhGtnOrderXmlParser < OpenChain::CustomHandler::GtNexus::GenericGtnOrderXmlParser

  def initialize
    super({})
  end

  def party_system_code party_xml, party_type
    id = nil
    if party_type == :vendor
      # Looks like there are multiple vendor numbers (for some reason), but we'll just pull the first
      id = reference_value(party_xml, "VendorNumber")
    elsif party_type == :factory
      id = reference_value(party_xml, "FactoryCode")
    end

    inbound_file.error_and_raise("Failed to find identifying information for #{party_type} on order # #{order_number(party_xml.parent)}.") if id.blank?

    id
  end

  def set_additional_party_information company, party_xml, party_type
    if party_type == :factory
      company.mid = identification_value(party_xml, "MFID")
    end
  end

  def set_additional_order_information order, order_xml
    terms_xml = order_xml.elements["orderTerms"]
    if terms_xml
      order.season = reference_value(terms_xml, "SeasonName")
      order.find_and_set_custom_value(cdefs[:ord_division], reference_value(terms_xml, "Division"))
      order.find_and_set_custom_value(cdefs[:ord_buyer_order_number], reference_value(terms_xml, "CustomerOrderNumber"))
      order.find_and_set_custom_value(cdefs[:ord_type], reference_value(terms_xml, "POTypeCode"))
    end
    nil
  end

  def set_additional_order_line_information order, order_line, item_xml
    # This is an extension point..by default it's left blank
    base_item = base_item_element(item_xml)
    order_line.find_and_set_custom_value(cdefs[:ord_line_color], item_identifier_value(base_item, "IdBuyerColor"))
    order_line.find_and_set_custom_value(cdefs[:ord_line_color_description], item_descriptor_value(base_item, "DescBuyerColor"))
    nil
  end

  def set_additional_product_information product, order_xml, line_xml
    changed = MutableBoolean.new false
    base_item = base_item_element(line_xml)
    set_custom_value(product, (reference_value(base_item, "FishAndWildlife") == "Y" ? true : nil), :prod_fish_wildlife, changed: changed)
    set_custom_value(product, reference_value(base_item, "ReportableFiberContent"), :prod_fabric_content, changed: changed)
    changed.value
  end

  def cdef_uids
    [:ord_division, :ord_buyer_order_number, :ord_type, :ord_line_color, :ord_line_color_description, :prod_fish_wildlife, :prod_fabric_content]
  end

  def importer_system_code order_xml
    "PVH"
  end

  def import_country order_xml, item_xml
    # For the moment, we're going to assume the country of final destination is the country code that we should be using
    # for the import country
    @country ||= begin
      code = order_xml.text "party[partyRoleCode = 'ShipmentDestination']/address/countryCode"
      country = nil
      if code && code.length > 1
        country = find_country(code[0, 2])
      end
      
      country
    end
    @country
  end

end; end; end; end;