module OpenChain; module Registries; class DefaultShipmentRegistry

  def self.can_cancel? shipment, user
    return shipment.canceled_date.nil? && shipment.can_edit?(user) && shipment.can_cancel_by_role?(user)
  end

  def self.can_uncancel? shipment, user
    return shipment.canceled_date && shipment.can_edit?(user) && shipment.can_cancel_by_role?(user)
  end

  def self.cancel_shipment_hook shipment, user
    # Does nothing by default.
  end

end; end; end;