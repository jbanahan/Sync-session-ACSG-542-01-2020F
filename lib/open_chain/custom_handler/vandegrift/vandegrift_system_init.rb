require 'open_chain/entity_compare/comparator_registry'
require 'open_chain/custom_handler/vandegrift/vandegrift_ace_entry_comparator'
require 'open_chain/custom_handler/hm/hm_entry_docs_comparator'
require 'open_chain/billing_comparators/product_comparator'
require 'open_chain/custom_handler/hm/hm_system_classify_product_comparator'

module OpenChain; module CustomHandler; module Vandegrift; class VandegriftSystemInit

  def self.init
    return unless MasterSetup.get.system_code == 'www-vfitrack-net'

    register_change_comparators
  end

  def self.register_change_comparators
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Vandegrift::VandegriftAceEntryComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Hm::HmEntryDocsComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::BillingComparators::ProductComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Hm::HmSystemClassifyProductComparator
  end
  private_class_method :register_change_comparators

end; end; end end