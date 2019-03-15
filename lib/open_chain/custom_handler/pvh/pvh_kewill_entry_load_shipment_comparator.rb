require 'open_chain/custom_handler/vandegrift/kewill_entry_load_shipment_comparator'

# Looks like we likely DO NOT need this comparator, and a multi-shipment setup is used instead for feeding to Kewill.  
# It is purposefully removed from the comparator setup and can likely be removed all-together once we're 100% live with PVH EDI data.
module OpenChain; module CustomHandler; module Pvh; class PvhKewillEntryLoadShipmentComparator < OpenChain::CustomHandler::Vandegrift::KewillEntryLoadShipmentComparator

  def self.has_entry_load_configured? shipment
    return false unless shipment.importer&.system_code == "PVH"

    return shipment.country_import&.iso_code.to_s.upcase == "US"
  end

end; end; end; end;