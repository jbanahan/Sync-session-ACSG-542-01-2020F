require 'open_chain/service_locator'
module OpenChain; module EntityCompare; module ComparatorRegistryHelper
  include OpenChain::ServiceLocator

  def check_validity comparator_class
    unless comparator_class.is_a?(Class)
      raise "All comparators must be a class"
    end
    unless comparator_class.respond_to?(:compare)
      raise "All comparators must respond to #compare"
    end
    unless comparator_class.respond_to?(:accept?)
      raise "All comparators must respond to #accept?"
    end
    nil
  end

end; end; end

