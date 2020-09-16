module OpenChain; module CustomHandler; module Target; class TargetSystemInit
  def self.init
    return unless MasterSetup.get.custom_feature? "Target"

    register_change_comparators
  end

  def self.register_change_comparators
    require 'open_chain/entity_compare/comparator_registry'
    require 'open_chain/custom_handler/target/target_entry_documents_comparator'

    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Target::TargetEntryDocumentsComparator
  end
  private_class_method :register_change_comparators
end; end; end; end
