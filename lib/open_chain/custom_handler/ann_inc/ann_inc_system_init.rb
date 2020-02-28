module OpenChain; module CustomHandler; module AnnInc; class AnnIncSystemInit
  def self.init
    return unless MasterSetup.get.custom_feature?("Ann Inc")
    
    register_change_comparators
  end

  def self.register_change_comparators
    require 'open_chain/custom_handler/custom_view_selector'
    require 'open_chain/custom_handler/ann_inc/ann_inc_view_selector'
    require 'open_chain/entity_compare/comparator_registry'
    require 'open_chain/custom_handler/ann_inc/ann_audit_comparator'
    require 'open_chain/custom_handler/ann_inc/ann_ac_date_comparator'
    require 'open_chain/custom_handler/ann_inc/ann_classification_default_comparator'

    OpenChain::CustomHandler::CustomViewSelector.register_handler OpenChain::CustomHandler::AnnInc::AnnIncViewSelector
    
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::AnnInc::AnnAuditComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::AnnInc::AnnAcDateComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::AnnInc::AnnClassificationDefaultComparator
  end
  private_class_method :register_change_comparators
end; end; end; end
