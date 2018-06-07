require 'open_chain/custom_handler/vandegrift/kewill_entry_load_shipment_comparator'
require 'open_chain/custom_handler/advance/advance_kewill_shipment_entry_xml_generator'
require 'open_chain/custom_handler/advance/carquest_fenix_nd_invoice_generator'

module OpenChain; module CustomHandler; module Advance; class AdvanceEntryLoadShipmentComparator < OpenChain::CustomHandler::Vandegrift::KewillEntryLoadShipmentComparator

  def self.has_entry_load_configured? shipment
    return ["ADVAN", "CQ"].include?(shipment.try(:importer).try(:system_code).to_s.upcase)
  end

  def trading_partner shipment
    system = determine_entry_system(shipment)

    system == :kewill ? "Kewill Entry" : "Fenix Entry"
  end

  def determine_entry_system shipment
    if shipment.country_import.try(:iso_code) == "US"
      return :kewill
    elsif shipment.country_import.try(:iso_code) == "CA"
      return :fenix
    else
      raise "Invalid Import Country '#{shipment.country_import.try(:iso_code)}' for Shipment '#{shipment.reference}'."
    end
  end

  def generate_and_send shipment, sync_record
    system = determine_entry_system(shipment) 
    if system == :kewill
      generate_and_send_kewill(shipment, sync_record)
    elsif system == :fenix
      generate_and_send_fenix(shipment, sync_record)
    else
      # Shouldn't happen
      raise "Invalid system #{system}."
    end
  end

  def generate_and_send_kewill shipment, sync_record
    xml = OpenChain::CustomHandler::Advance::AdvanceKewillShipmentEntryXmlGenerator.new.generate_xml shipment
    Tempfile.open(["ci_load_#{shipment.reference}_", ".xml"]) do |file|
      xml.write file
      file.flush

      ftp_sync_file file, sync_record, ecs_connect_vfitrack_net("kewill_edi/to_kewill")
    end
  end

  def generate_and_send_fenix shipment, sync_record
    OpenChain::CustomHandler::Advance::CarquestFenixNdInvoiceGenerator.new.generate_invoice_and_send shipment, sync_record
  end

end; end; end; end