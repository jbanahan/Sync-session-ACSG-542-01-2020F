module StatusableSupport  
  
  def set_status
    return nil if self.id.nil?
    #self.class::CORE_MODULE.class_name seems like a big loop, but it allows us to reference a different class as the "Core class"
    rules = StatusRule.where("module_type = ?", statusable_core_module.class_name).order("test_rank")
    self.status_rule = matching_rule rules
  end
  
  def status_name
    return self.status_rule.name unless self.status_rule.nil?
  end

  def statusable_core_module
    CoreModule.find_by_class_name(self.class.to_s)
  end
  
  private

  def matching_rule(rules)
    rules.each do |r|
      qry = self.class.where("#{statusable_core_module.table_name}.id = ?",self.id)    
      r.search_criterions.each do |c|
        qry = c.apply(qry)
      end
      return r if qry.count==1
    end
    return nil
  end
end