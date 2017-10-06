require 'open_chain/entity_compare/comparator_registry'
require 'open_chain/custom_handler/vandegrift/vandegrift_ace_entry_comparator'
require 'open_chain/custom_handler/hm/hm_entry_docs_comparator'
require 'open_chain/billing_comparators/product_comparator'
require 'open_chain/custom_handler/hm/hm_system_classify_product_comparator'
require 'open_chain/custom_handler/under_armour/under_armour_shipment_comparator'
require 'open_chain/custom_handler/ascena/ascena_entry_billing_comparator'
require 'open_chain/entity_compare/product_comparator/stale_tariff_comparator'
require 'open_chain/custom_handler/vandegrift/kewill_isf_backfill_comparator'
require 'open_chain/custom_handler/vandegrift/kewill_ci_load_shipment_comparator'
require 'open_chain/custom_handler/talbots/talbots_landed_cost_comparator'
require 'open_chain/custom_handler/vandegrift/kewill_ci_load_isf_comparator'

module OpenChain; module CustomHandler; module Vandegrift; class VandegriftSystemInit

  def self.init
    code = MasterSetup.get.system_code
    return unless ['www-vfitrack-net', 'test'].include? code

    register_change_comparators
  end

  def self.register_change_comparators
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Vandegrift::VandegriftAceEntryComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Hm::HmEntryDocsComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::BillingComparators::ProductComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Hm::HmSystemClassifyProductComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Ascena::AscenaEntryBillingComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::EntityCompare::ProductComparator::StaleTariffComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::UnderArmour::UnderArmourShipmentComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Vandegrift::KewillIsfBackfillComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Vandegrift::KewillCiLoadShipmentComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Talbots::TalbotsLandedCostComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Vandegrift::KewillCiLoadIsfComparator
  end
  private_class_method :register_change_comparators

end; end; end end
