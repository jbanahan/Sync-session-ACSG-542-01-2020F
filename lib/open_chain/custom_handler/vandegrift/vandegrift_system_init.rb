module OpenChain; module CustomHandler; module Vandegrift; class VandegriftSystemInit

  def self.init
    return unless MasterSetup.get.custom_feature?("WWW")

    register_change_comparators
  end
  
  def self.register_change_comparators
    # Add the requires here, so that they're not loaded on every single customer system, when there's no need for them on those
    require 'open_chain/entity_compare/comparator_registry'
    require 'open_chain/billing_comparators/product_comparator'
    require 'open_chain/custom_handler/hm/hm_entry_docs_comparator'
    require 'open_chain/custom_handler/hm/hm_entry_parts_comparator'
    require 'open_chain/custom_handler/hm/hm_system_classify_product_comparator'
    require 'open_chain/custom_handler/under_armour/under_armour_shipment_comparator'
    require 'open_chain/custom_handler/ascena/ascena_entry_billing_comparator'
    require 'open_chain/entity_compare/product_comparator/stale_tariff_comparator'
    require 'open_chain/custom_handler/talbots/talbots_landed_cost_comparator'
    require 'open_chain/custom_handler/foot_locker/foot_locker_entry_810_comparator'
    require 'open_chain/custom_handler/advance/advance_entry_load_shipment_comparator'
    require 'open_chain/custom_handler/pvh/pvh_invoice_comparator'
    require 'open_chain/custom_handler/pvh/pvh_entry_billing_comparator'
    require 'open_chain/custom_handler/vandegrift/kewill_isf_backfill_comparator'
    require 'open_chain/custom_handler/vandegrift/kewill_ci_load_isf_comparator'
    require 'open_chain/custom_handler/vandegrift/vandegrift_entry_archive_comparator'
    require 'open_chain/custom_handler/vandegrift/kewill_ci_load_shipment_comparator'
    require 'open_chain/custom_handler/vandegrift/kewill_entry_load_shipment_comparator'
    require 'open_chain/custom_handler/vandegrift/kewill_invoice_ci_load_comparator'

    
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::BillingComparators::ProductComparator

    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Hm::HmEntryDocsComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Hm::HmEntryPartsComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Hm::HmSystemClassifyProductComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Ascena::AscenaEntryBillingComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::EntityCompare::ProductComparator::StaleTariffComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::UnderArmour::UnderArmourShipmentComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Talbots::TalbotsLandedCostComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::FootLocker::FootLockerEntry810Comparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Advance::AdvanceEntryLoadShipmentComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Pvh::PvhInvoiceComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Pvh::PvhEntryBillingComparator

    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Vandegrift::KewillIsfBackfillComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Vandegrift::KewillEntryLoadShipmentComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Vandegrift::KewillCiLoadIsfComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Vandegrift::VandegriftEntryArchiveComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Vandegrift::KewillCiLoadShipmentComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Vandegrift::KewillInvoiceCiLoadComparator
  end
  private_class_method :register_change_comparators

end; end; end end
