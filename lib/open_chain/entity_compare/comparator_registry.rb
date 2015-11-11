module OpenChain; module EntityCompare; class ComparatorRegistry
  REGISTERED_ITEMS ||= Set.new

  # register a new comparator.  Must be a class that responds to #compare
  def self.register comparator_class
    unless comparator_class.is_a?(Class)
      raise "Comparator must be a class so that cloning and calling objects across instances doesn't cause side effects."
    end
    unless comparator_class.respond_to?(:compare)
      raise "All comparators must respond to #compare"
    end
    REGISTERED_ITEMS << comparator_class
    nil
  end

  # get an Enumerable of all comparators
  #
  # Intended usage is `OpenChain::EntityCompare::ComparatorRegistry.registered.each {|c| c.compare ...}`
  #
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
end; end; end;