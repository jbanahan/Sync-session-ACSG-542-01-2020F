module JoinSupport
#used to help classes add SQL join statements based on module chains

  def set_module_chain base_search_object
  #if the class is linked to search_setup, get the module chain from there, else get it from the CoreModule
  #sets the value to the internal @module_chain variable
  #implementing class must have either self.model_field_uid or self.search_setup
    if respond_to?('search_setup') && !self.search_setup.nil?
      @module_chain = self.search_setup.module_chain
    else
      cm = CoreModule.find_by_class_name(base_search_object.klass.to_s)
      if cm.nil?
        @module_chain = nil
      else
        @module_chain = cm.default_module_chain
      end
    end
  end

  def add_join(p)
    mf = find_model_field
    set_module_chain p if @module_chain.nil?
    mf_cm = mf.core_module
    p = add_parent_joins p, @module_chain, mf_cm unless @module_chain.nil?
    p = p.joins(mf.join_statement) unless mf.join_statement.nil?
    p
  end

  private
  def add_parent_joins(p,module_chain,target_module)
    add_parent_joins_recursive p, module_chain, target_module, module_chain.first
  end
  
  def add_parent_joins_recursive(p, module_chain, target_module, current_module) 
    new_p = p
    child_module = module_chain.child current_module
    unless child_module.nil?
      child_join = current_module.child_joins[child_module]
      new_p = p.joins(child_join) unless child_join.nil?
      unless child_module==target_module
        new_p = add_parent_joins_recursive new_p, module_chain, target_module, child_module
      end
    end
    new_p
  end
end
