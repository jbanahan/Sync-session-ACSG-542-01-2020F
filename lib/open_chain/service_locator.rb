module OpenChain; module ServiceLocator
  def register obj
    # implementations of check_validity should raise exceptions if
    # not valid
    check_validity(obj) if self.respond_to?(:check_validity)
    internal_registry << obj
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
end; end
