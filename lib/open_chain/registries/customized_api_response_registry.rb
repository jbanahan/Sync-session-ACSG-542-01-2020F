require 'open_chain/service_locator'
require 'open_chain/registries/registry_support'

# The idea here is to be able to register custom classes that can mutate the standard API response hash 
# on a custom basis and to easily provide custom API variants.
#
# This can be useful for providing custom flags on custom views or other custom fields needed for custom 
# display logic.
module OpenChain; module Registries; class CustomizedApiResponseRegistry
  extend OpenChain::ServiceLocator
  extend OpenChain::Registries::RegistrySupport

  def self.customize_order_response order, user, order_hash, params
    customize_response(:order, order, user, order_hash, params)
  end

  def self.customize_shipment_response shipment, user, shipment_hash, params
    customize_response(:shipment, shipment, user, shipment_hash, params)
  end

  def self.customize_product_response product, user, product_hash, params
    customize_response(:product, product, user, product_hash, params)
  end

  def self.customize_response response_type, obj, user, api_obj, params
    evaluate_all_registered("customize_#{response_type}_response".to_sym, obj, user, api_obj, params)
    api_obj
  end
  private_class_method :customize_response

end; end; end;