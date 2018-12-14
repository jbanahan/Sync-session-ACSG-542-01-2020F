require 'open_chain/custom_handler/vandegrift/kewill_entry_load_shipment_comparator'

module OpenChain; module CustomHandler; module Pvh; class PvhKewillEntryLoadShipmentComparator < OpenChain::CustomHandler::Vandegrift::KewillEntryLoadShipmentComparator

  def self.has_entry_load_configured? shipment
    return false unless shipment.importer&.system_code == "PVH"

    return shipment.country_import&.iso_code.to_s.upcase == "US"
  end

end; end; end; end;