require 'open_chain/custom_handler/gt_nexus/abstract_gtn_asn_xml_parser'
require 'open_chain/custom_handler/vandegrift/kewill_entry_load_shipment_comparator'

module OpenChain; module CustomHandler; module Pvh; class PvhGtnAsnXmlParser < OpenChain::CustomHandler::GtNexus::AbstractGtnAsnXmlParser

  def initialize
    super({create_missing_purchase_orders: true})
    @sent_containers = Set.new
  end

  def importer_system_code _xml
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

  def finalize_shipment shipment, _xml
    # I'm not sure if this is a widespread GTN thing or localized to PVH, but if any container numbers (or house bills)
    # change, then we'll get them as new records and thus we need to remove the old ones.
    # The XML looks to include the whole list of containers (we don't get partials) so we should be safe doing this.
    remove_unreferenced_containers(shipment, @sent_containers)

    # This indicates to our Kewill entry xml generator that the data is ready to be sent to Kewill.
    set_custom_value(shipment, :shp_entry_prepared_date, nil, Time.zone.now)
    # We also clear out any existing sync records for the Kewill Entry every time the shipment comes in...this forces a resend to
    # Kewill on each shipment update.
    sr = shipment.sync_records.find {|sync| sync.trading_partner == OpenChain::CustomHandler::Vandegrift::KewillEntryLoadShipmentComparator::TRADING_PARTNER}
    sr.sent_at = nil if sr.present?

    nil
  end

  def set_additional_shipment_information shipment, _shipment_xml
    # PVH's ASNs sometimes don't have MasterBills (house bills instead).  Not sure how widespread this is...so I don't want to put it into the
    # generic parser at the moment.
    if shipment.master_bill_of_lading.blank? && shipment.house_bill_of_lading.present?
      shipment.master_bill_of_lading = shipment.house_bill_of_lading
      shipment.house_bill_of_lading = nil
    end

    shipment.description_of_goods = "WEARING APPAREL"

    nil
  end

  def set_additional_shipment_line_information _shipment, _container, line, line_xml
    line.mid = find_invoice_line(line_xml)&.mid

    nil
  end

  def set_additional_container_information _shipment, container, _container_xml
    @sent_containers << container.container_number
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

  def remove_unreferenced_containers shipment, container_numbers_from_xml
    shipment.containers.each do |container|
      container.destroy unless container_numbers_from_xml.include?(container.container_number)
    end

    # There are cases where the data might have originally been sent without a container (truck this is especially likely for)
    # and then updated later to add the trailer number.  In this case, we need to make sure that
    # we remove any shipment lines that do not have a container number.
    if container_numbers_from_xml.length > 0 && !container_numbers_from_xml.include?("") && !container_numbers_from_xml.include?(nil)
      shipment.shipment_lines.each do |line|
        line.destroy if line.container.nil?
      end
    end
  end

  # This overrides the default abstract gtn master bill behavior by not prefixing
  # the CarrierCode onto the BLNumber given in the MasterBLNumber.  The data in the
  # shipment needs to match exactly to what's in GTN when we later reference this
  # value from the entry and also send it via the GTN billing xml.
  def find_master_bill xml
    xml.text "Container/LineItems/MasterBLNumber"
  end

end; end; end; end