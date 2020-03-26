require 'open_chain/custom_handler/gt_nexus/abstract_gtn_invoice_xml_parser'

module OpenChain; module CustomHandler; module GtNexus; class GenericGtnInvoiceXmlParser < OpenChain::CustomHandler::GtNexus::AbstractGtnInvoiceXmlParser

  def initialize
    super({link_to_orders: false})
  end

  def importer_system_code invoice_xml
    # I don't think we can count on any real identifier data being sent in the GTN XML in the generic case.
    # So, we're going to try finding the code 1 of two ways.  By looking for the
    # consignee associated with the partyUid and then falling back to the Name
    consignee_xml = REXML::XPath.first(invoice_xml, "party[partyRoleCode = 'Consignee']")
    inbound_file.reject_and_raise("No 'Consignee' party found.") if consignee_xml.nil?

    uid = consignee_xml.text "partyUid"
    name = consignee_xml.text "name"
    importer = find_importer(uid) unless uid.blank?
    if importer.nil?
      importer = find_importer(name) unless name.blank?
    end

    inbound_file.reject_and_raise("No 'GT Nexus Invoice Consignee' System Identifier present for values '#{uid}' or '#{name}'. Please add identifier in order to process this file.") if importer.nil?
    inbound_file.reject_and_raise("Importer '#{importer.name}' must have a system code configured in order to receive GTN Invoice xml.") if importer.system_code.blank?

    importer.system_code
  end

  def party_map
    {vendor: "party[partyRoleCode = 'Seller']", factory: "party[partyRoleCode = 'OriginOfGoods']"}
  end

  def party_system_code party_xml, party_type
    party_xml.text "memberId"
  end

  def find_importer code
    Company.where(importer: true).joins(:system_identifiers).where(system_identifiers: {system: "GT Nexus Invoice Consignee", code: code}).first
  end

end; end; end; end;
