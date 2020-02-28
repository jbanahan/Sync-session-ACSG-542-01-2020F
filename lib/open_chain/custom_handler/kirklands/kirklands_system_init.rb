module OpenChain; module CustomHandler; module Kirklands; class KirklandsSystemInit

  def self.init
    return unless MasterSetup.get.custom_feature? "Kirklands"

    register_change_comparators
  end

  def self.register_change_comparators
    require 'open_chain/entity_compare/comparator_registry'
    require 'open_chain/custom_handler/kirklands/kirklands_entry_duty_comparator'

    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::Kirklands::KirklandsEntryDutyComparator
  end
  private_class_method :register_change_comparators

end; end; end; end