require 'open_chain/custom_handler/gt_nexus/generic_gtn_invoice_xml_parser'

module OpenChain; module CustomHandler; module Rockport; class RockportGtnInvoiceXmlParser < OpenChain::CustomHandler::GtNexus::GenericGtnInvoiceXmlParser

  def importer_system_code invoice_xml
    "THEROC"
  end

  def set_additional_invoice_line_information invoice, invoice_line, item_xml
    base_item = item_xml.elements["baseItem"]
    invoice_line.part_number = item_identifier_value(base_item, "SkuNumber")
    invoice_line
  end

end; end; end; end;
