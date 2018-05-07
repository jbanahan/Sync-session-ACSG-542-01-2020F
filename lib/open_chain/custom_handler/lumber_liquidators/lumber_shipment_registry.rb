require 'open_chain/registries/default_shipment_registry'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberShipmentRegistry < OpenChain::Registries::DefaultShipmentRegistry

  def self.can_uncancel? shipment, user
    return false
  end

  def self.cancel_shipment_hook shipment, user
    # Lumber shipments need to have all booking lines destroyed upon cancellation.
    shipment.booking_lines.destroy_all
  end

end; end; end; end;