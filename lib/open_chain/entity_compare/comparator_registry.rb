require 'open_chain/service_locator'
module OpenChain; module EntityCompare; class ComparatorRegistry
  extend OpenChain::ServiceLocator

  def self.check_validity comparator_class
    unless comparator_class.is_a?(Class)
      raise "All comparators must be a class"
    end
    unless comparator_class.respond_to?(:compare)
      raise "All comparators must respond to #compare"
    end
    unless comparator_class.respond_to?(:accept?)
      raise "All comparators must respond to #accept?"
    end

    REGISTERED_ITEMS << comparator_class
    nil
  end

  def self.registered
    REGISTERED_ITEMS.clone
  end

  # remove a comparator
  def self.remove comparator_class
    REGISTERED_ITEMS.delete(comparator_class)
  end

  def self.clear
    REGISTERED_ITEMS.clear
  end

  # get an Enumerable of all comparators that will accept the given snapshot
  #
  # Intended usage is `OpenChain::EntityCompare::ComparatorRegistry.registered_for(snapshot) {|c| c.compare ...}`
  #
  def self.registered_for snapshot
    registered.find_all {|r| r.respond_to?(:accept?) && r.accept?(snapshot)}
  end

end; end; end;
