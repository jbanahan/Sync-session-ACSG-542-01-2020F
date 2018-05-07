require 'open_chain/service_locator'
require 'open_chain/registries/registry_support'

module OpenChain; module Registries; class ShipmentRegistry
  extend OpenChain::ServiceLocator
  extend OpenChain::Registries::RegistrySupport

  def self.check_validity reg_class
    check_registration_validity(reg_class, "Shipment", [:can_cancel?, :can_uncancel?])
  end

  def self.can_cancel? shipment, user
    evaluate_registered_permission(:can_cancel?, shipment, user)
  end

  def self.can_uncancel? shipment, user
    evaluate_registered_permission(:can_uncancel?, shipment, user)
  end

  def self.cancel_shipment_hook shipment, user
    evaluate_all_registered(:cancel_shipment_hook, shipment, user)
  end

end; end; end
