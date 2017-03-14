require 'open_chain/custom_handler/polo/polo_system_classify_product_comparator'

module OpenChain; module CustomHandler; module Polo; class PoloSystemInit
  def self.init
    return unless MasterSetup.get.system_code == "polo" || MasterSetup.get.system_code == "polotest"

    register_change_comparators
  end

  def self.register_change_comparators
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Polo::PoloSystemClassifyProductComparator
  end
  private_class_method :register_change_comparators
end; end; end; end