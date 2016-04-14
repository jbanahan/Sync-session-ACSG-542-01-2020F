require 'open_chain/custom_handler/custom_view_selector'
require 'open_chain/custom_handler/lumber_liquidators/lumber_view_selector'
require 'open_chain/custom_handler/lumber_liquidators/lumber_order_change_comparator'
require 'open_chain/custom_handler/lumber_liquidators/lumber_product_vendor_assignment_change_comparator'
require 'open_chain/entity_compare/comparator_registry'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberSystemInit
  def self.init
    return unless MasterSetup.get.system_code == 'll'

    OpenChain::CustomHandler::CustomViewSelector.register_handler OpenChain::CustomHandler::LumberLiquidators::LumberViewSelector

    register_change_comparators
  end

  def self.register_change_comparators
    [
      OpenChain::CustomHandler::LumberLiquidators::LumberOrderChangeComparator,
      OpenChain::CustomHandler::LumberLiquidators::LumberProductVendorAssignmentChangeComparator
    ].each {
      |c| OpenChain::EntityCompare::ComparatorRegistry.register c
    }
  end
  private_class_method :register_change_comparators
end; end; end; end
