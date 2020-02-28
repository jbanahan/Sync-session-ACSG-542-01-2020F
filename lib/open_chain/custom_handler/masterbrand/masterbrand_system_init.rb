module OpenChain; module CustomHandler; module Masterbrand; class MasterbrandSystemInit

  def self.init
    return unless MasterSetup.get.custom_feature?("MBCI")

    register_change_comparators
  end

  def self.register_change_comparators
    require 'open_chain/entity_compare/comparator_registry'
    require 'open_chain/billing_comparators/entry_comparator'

    OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::BillingComparators::EntryComparator
  end
  private_class_method :register_change_comparators

end; end; end end
