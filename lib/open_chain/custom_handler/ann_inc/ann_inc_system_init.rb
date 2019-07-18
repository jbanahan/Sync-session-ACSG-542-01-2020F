require 'open_chain/custom_handler/custom_view_selector'
require 'open_chain/custom_handler/ann_inc/ann_inc_view_selector'
require 'open_chain/entity_compare/comparator_registry'
require 'open_chain/custom_handler/ann_inc/ann_audit_comparator'
require 'open_chain/custom_handler/ann_inc/ann_ac_date_comparator'
require 'open_chain/custom_handler/ann_inc/ann_classification_default_comparator'

module OpenChain; module CustomHandler; module AnnInc; class AnnIncSystemInit
  def self.init
    return unless ['ann','ann-test'].include? MasterSetup.get.system_code
    OpenChain::CustomHandler::CustomViewSelector.register_handler OpenChain::CustomHandler::AnnInc::AnnIncViewSelector
    register_change_comparators
  end

  def self.register_change_comparators
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::AnnInc::AnnAuditComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::AnnInc::AnnAcDateComparator
    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::AnnInc::AnnClassificationDefaultComparator
  end
  private_class_method :register_change_comparators
end; end; end; end
