class ValidationRuleFieldFormat < BusinessValidationRule
  def should_skip? obj
    r = false
    self.search_criterions.each do |sc|
      return true if !sc.test?(obj)
    end
    r
  end
  def run_validation obj
    attrs = self.rule_attributes
    mf = ModelField.find_by_uid attrs['model_field_uid']
    val = mf.process_export(obj,nil,true)
    reg = attrs['regex']
    return nil if attrs['allow_blank'] && val.blank?
    if !val.to_s.match(reg)
      return "#{mf.label} must match '#{reg}' format, but was '#{val}'"      
    end
    nil
  end
end
