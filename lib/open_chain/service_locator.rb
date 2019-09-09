module OpenChain; module ServiceLocator
  def register obj

    registries = obj.respond_to?(:child_services) ? obj.child_services : [obj]

    # implementations of check_validity should raise exceptions if
    # not valid
    registries.each {|r| check_validity(r) } if self.respond_to?(:check_validity)
    
    add_to_internal_registry registries
    # Use the 'registered' callback to notify the class it has been registered
    Array.wrap(registries).each { |o| o.registered if o.respond_to?(:registered) }

    self
  end

  def registered
    internal_registry.clone
  end

  def remove obj
    internal_registry.delete(obj)
    self
  end

  def clear
    internal_registry.clear
    self
  end

  def internal_registry
    @reg ||= Set.new
    @reg
  end

  def add_to_internal_registry obj
    internal_registry.merge Array.wrap(obj)
    nil
  end
end; end
