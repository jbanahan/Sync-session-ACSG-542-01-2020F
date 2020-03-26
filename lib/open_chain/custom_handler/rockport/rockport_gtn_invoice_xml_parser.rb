require 'open_chain/custom_handler/gt_nexus/generic_gtn_invoice_xml_parser'

module OpenChain; module CustomHandler; module Rockport; class RockportGtnInvoiceXmlParser < OpenChain::CustomHandler::GtNexus::GenericGtnInvoiceXmlParser

  def importer_system_code invoice_xml
    system_code = super
    inbound_file.reject_and_raise("Customer system code #{system_code} is not valid for this parser. Parser is only for Rockport and Reef.") if system_code != "REEF" && system_code != "THEROC"

    system_code
  end

  def set_additional_invoice_line_information invoice, invoice_line, item_xml
    base_item = item_xml.elements["baseItem"]
    invoice_line.part_number = item_identifier_value(base_item, "SkuNumber")
    invoice_line
  end

end; end; end; end;
