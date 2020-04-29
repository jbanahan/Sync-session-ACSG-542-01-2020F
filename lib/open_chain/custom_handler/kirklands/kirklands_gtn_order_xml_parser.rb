require 'open_chain/custom_handler/gt_nexus/abstract_gtn_simple_order_xml_parser'
require 'open_chain/custom_handler/kirklands/kirklands_custom_definition_support'

module OpenChain; module CustomHandler; module Kirklands; class KirklandsGtnOrderXmlParser < OpenChain::CustomHandler::GtNexus::AbstractGtnSimpleOrderXmlParser
  include OpenChain::CustomHandler::Kirklands::KirklandsCustomDefinitionSupport

  def initialize
    super({})
  end

  def set_additional_order_information order, order_xml
    xml = order_header_element(order_xml)

    order.find_and_set_custom_value(cdefs[:ord_department_code], et(xml, "CustomerDepartmentCode"))
    order.find_and_set_custom_value(cdefs[:ord_department], et(xml, "CustomerDepartmentName"))

    nil
  end

  def set_additional_order_line_information order, order_line, line_xml
    # The Kirklands mapping is kind of weird on the price mappings...for that reason, we're going to override
    # the default mapping
    order_line.price_per_unit = BigDecimal(et(line_xml, "FirstCostPrice", true))
    order_line.unit_msrp = BigDecimal(et(line_xml, "RetailCostPrice", true))

    nil
  end

  def set_additional_product_information product, order_xml, line_xml
    changed = MutableBoolean.new false

    set_custom_value(product, BigDecimal(et(line_xml, "FirstCostPrice", true)), :prod_fob_price, changed: changed)
    set_custom_value(product, et(line_xml, "Origin/CountryCode"), :prod_country_of_origin, changed: changed)
    set_custom_value(product, et(line_xml, "ProdReferenceNumber2"), :prod_vendor_item_number, changed: changed)

    changed.value
  end

  def cdef_uids
    [:ord_department, :ord_department_code, :prod_fob_price, :prod_country_of_origin, :prod_vendor_item_number]
  end

  def importer_system_code order_xml
    "KLANDS"
  end

  def import_country order_xml, item_xml
    country = et(item_xml, "PortOfDischarge/CountryCode")
    if country.blank?
      country = "US"
    end

    find_country(country)
  end

end; end; end; end;