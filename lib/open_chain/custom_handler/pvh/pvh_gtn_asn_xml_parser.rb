require 'open_chain/custom_handler/gt_nexus/generic_gtn_asn_xml_parser'
require 'open_chain/custom_handler/vandegrift/kewill_entry_load_shipment_comparator'

module OpenChain; module CustomHandler; module Pvh; class PvhGtnAsnXmlParser < OpenChain::CustomHandler::GtNexus::GenericGtnAsnXmlParser

  def initialize
    super({})
  end

  def importer_system_code xml
    "PVH"
  end

  def party_system_code party_xml, party_type
    id = nil
    if [:vendor].include? party_type
      id = party_xml.text "Code"
    end

    inbound_file.reject_and_raise("Failed to find identifying information for #{party_type} on Shipment # #{shipment_reference(party_xml.parent)}.") if id.blank?

    id
  end

  def finalize_shipment shipment, xml
    # This indicates to our Kewill entry xml generator that the data is ready to be sent to Kewill.
    set_custom_value(shipment, Time.zone.now, :shp_entry_prepared_date)
    # We also clear out any existing sync records for the Kewill Entry every time the shipment comes in...this forces a resend to 
    # Kewill on each shipment update.
    sr = shipment.sync_records.find {|sr| sr.trading_partner == OpenChain::CustomHandler::Vandegrift::KewillEntryLoadShipmentComparator::TRADING_PARTNER}
    sr.sent_at = nil if sr.present?

    nil
  end

  def set_additional_shipment_information shipment, shipment_xml
    # PVH's ASNs sometimes don't have MasterBills (house bills instead).  Not sure how widespread this is...so I don't want to put it into the 
    # generic parser at the moment.
    if shipment.master_bill_of_lading.blank? && !shipment.house_bill_of_lading.blank?
      shipment.master_bill_of_lading = shipment.house_bill_of_lading
      shipment.house_bill_of_lading = nil
    end

    shipment.description_of_goods = "WEARING APPAREL"

    nil
  end

  def set_additional_shipment_line_information shipment, container, line, line_xml
    line.mid = find_invoice_line(line_xml)&.mid

    nil
  end

  def set_additional_container_information shipment, container, container_xml
    container.goods_description = "WEARING APPAREL"
  end

  def find_invoice_line line_xml
    invoice_number = line_xml.text "InvoiceNumber"
    order_number = line_xml.text "PONumber"
    part_number = line_xml.text "ProductCode"

    return nil if invoice_number.blank? || order_number.blank? || part_number.blank?

    invoice = find_invoice(invoice_number)
    return nil unless invoice

    invoice.invoice_lines.find {|line| line.po_number == order_number && line.part_number == part_number }
  end

  def find_invoice invoice_number
    @invoices ||= Hash.new do |h, k|
      h[k] = Invoice.where(invoice_number: k, importer_id: importer.id).first
    end

    @invoices[invoice_number]
  end

  def cdef_uids
    [:shp_entry_prepared_date]
  end

end; end; end; end