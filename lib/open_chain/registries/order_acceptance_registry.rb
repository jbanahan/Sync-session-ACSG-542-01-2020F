require 'open_chain/service_locator'
require 'open_chain/registries/registry_support'

module OpenChain; module Registries; class OrderAcceptanceRegistry
  extend OpenChain::ServiceLocator
  extend OpenChain::Registries::RegistrySupport

  def self.check_validity reg_class
    check_registration_validity(reg_class, "OrderAcceptance", [:can_accept?, :can_be_accepted?])
  end

  def self.can_accept? order, user
    evaluate_registered_permission(:can_accept?, order, user)
  end

  def self.can_be_accepted? order
    evaluate_registered_permission(:can_be_accepted?, order)
  end

end; end; end
