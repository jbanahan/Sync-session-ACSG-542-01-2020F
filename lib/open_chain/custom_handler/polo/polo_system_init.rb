require 'open_chain/custom_handler/polo/polo_system_classify_product_comparator'
require 'open_chain/custom_handler/polo/polo_fda_product_comparator'
require 'open_chain/custom_handler/polo/polo_non_textile_product_comparator'

module OpenChain; module CustomHandler; module Polo; class PoloSystemInit
  def self.init
    return unless MasterSetup.get.custom_feature? "Polo"

    register_change_comparators
  end

  def self.register_change_comparators
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Polo::PoloSystemClassifyProductComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Polo::PoloFdaProductComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Polo::PoloNonTextileProductComparator
  end
  private_class_method :register_change_comparators
  
end; end; end; end
