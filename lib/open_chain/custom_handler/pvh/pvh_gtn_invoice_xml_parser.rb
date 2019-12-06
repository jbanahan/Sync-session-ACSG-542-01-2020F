require 'open_chain/custom_handler/gt_nexus/abstract_gtn_invoice_xml_parser'

module OpenChain; module CustomHandler; module Pvh; class PvhGtnInvoiceXmlParser < OpenChain::CustomHandler::GtNexus::AbstractGtnInvoiceXmlParser

  def initialize
    super({})
  end

  def importer_system_code invoice_xml
    "PVH"
  end

  def party_map
    # It appears that PVH's Invoice doesn't use a consistent FactoryCode identifiery for the Factory (like
    # the PO does).  Therefore, I'm just going to skip parsing the factory - the MID is included for them 
    # at the invoice line level anyway (which is also not included in the party either).  If we REALLY need one, 
    # we should be able to link to the PO at the invoice line level.
    {vendor: "party[partyRoleCode = 'Seller']", ship_to: "party[partyRoleCode = 'ShipmentDestination']", consignee: "party[partyRoleCode = 'Consignee']"}
  end

  def party_system_code party_xml, party_type
    id = nil
    if party_type == :vendor
      # Looks like there are multiple vendor numbers (for some reason), but we'll just pull the first
      id = reference_value(party_xml, "VendorNumber")
    elsif party_type == :ship_to
      id = party_xml.text "name"
    elsif party_type == :consignee
      id = reference_value(party_xml, "ConsigneeCode")
    end

    id
  end

  def set_additional_invoice_information invoice, xml
    terms = xml.elements["invoiceTerms"]
    if terms
      invoice.customer_reference_number = reference_value(terms, "AsnNumber")
    end
    nil
  end

  def set_additional_invoice_line_information invoice, invoice_line, item_xml
    base_item = item_xml.elements["baseItem"]

    invoice_line.fish_wildlife = reference_value(base_item, "FishAndWildlife").to_s.upcase == "Y"
    invoice_line.mid = reference_value(base_item, "MIDNumber")
    if country = reference_value(base_item, "FactoryCountryCode")
      invoice_line.country_origin = find_country(country)
    end
    invoice_line.part_description = reference_value(base_item, "CustomsHTSText")
    cartons = reference_value(base_item, "TotalNumberOfCartons")
    invoice_line.cartons = cartons.to_i unless cartons.blank?
    invoice_line.customs_quantity = BigDecimal(reference_value(base_item, "CustomsUnits").to_s)
    
    invoice_line
  end

end; end; end; end