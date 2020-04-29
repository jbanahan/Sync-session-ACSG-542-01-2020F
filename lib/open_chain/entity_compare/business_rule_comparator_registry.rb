require 'open_chain/entity_compare/comparator_registry_helper'

module OpenChain; module EntityCompare; class BusinessRuleComparatorRegistry
  extend OpenChain::EntityCompare::ComparatorRegistryHelper

  # get an Enumerable of all comparators that will accept the given snapshot
  #
  # Intended usage is `OpenChain::EntityCompare::ComparatorRegistry.registered_for(snapshot) {|c| c.compare ...}`
  #
  def self.registered_for snapshot
    registered.find_all {|r| snapshot.kind_of?(BusinessRuleSnapshot) && r.respond_to?(:accept?) && r.accept?(snapshot)}
  end

end; end; end;
