require 'open_chain/order_acceptance_registry'
require 'open_chain/custom_handler/custom_view_selector'
require 'open_chain/custom_handler/lumber_liquidators/lumber_view_selector'
require 'open_chain/custom_handler/lumber_liquidators/lumber_order_acceptance'
require 'open_chain/custom_handler/lumber_liquidators/lumber_order_change_comparator'
require 'open_chain/custom_handler/lumber_liquidators/lumber_product_change_comparator'
require 'open_chain/custom_handler/lumber_liquidators/lumber_product_vendor_assignment_change_comparator'
require 'open_chain/entity_compare/comparator_registry'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberSystemInit
  def self.init
    return unless ['ll','ll-test'].include? MasterSetup.get.system_code

    OpenChain::CustomHandler::CustomViewSelector.register_handler OpenChain::CustomHandler::LumberLiquidators::LumberViewSelector
    OpenChain::OrderAcceptanceRegistry.register OpenChain::CustomHandler::LumberLiquidators::LumberOrderAcceptance

    register_change_comparators
  end

  def self.register_change_comparators
    [
      OpenChain::CustomHandler::LumberLiquidators::LumberOrderChangeComparator,
      OpenChain::CustomHandler::LumberLiquidators::LumberProductVendorAssignmentChangeComparator,
      OpenChain::CustomHandler::LumberLiquidators::LumberProductChangeComparator
    ].each {
      |c| OpenChain::EntityCompare::ComparatorRegistry.register c
    }
  end
  private_class_method :register_change_comparators
end; end; end; end
