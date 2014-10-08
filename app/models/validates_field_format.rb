module ValidatesFieldFormat

  def validate_field_format obj, opt = {}
    opt = {yield_matches: false, yield_failures: true}.merge opt

    # Memoize the attributes and model field, there's no need to have to deserialze them and do the model field lookup repeatedly
    # for any rule that runs over child objects. These values shouldn't change over the validation lifespan of the rule.
    val = model_field.process_export(obj,nil,true)
    reg = match_expression

    message = nil
    unless allow_blank? && val.blank?
      if !val.to_s.match(reg)
        if opt[:yield_failures] && block_given?
          message = yield model_field, val, reg
        else
          message = "#{model_field.label} must match '#{reg}' format, but was '#{val}'"      
        end
      elsif opt[:yield_matches] && block_given?
        yield model_field, val, reg
      end
    end
    
    message
  end

  def match_expression
    @regex ||= rule_attribute('regex')
    @regex
  end

  def model_field
    @model_field ||= ModelField.find_by_uid rule_attribute('model_field_uid')
    @model_field
  end

  def allow_blank?
    @allow_blank ||= rule_attribute('allow_blank')
    @allow_blank
  end

  def rule_attribute key
    @attrs ||= self.rule_attributes
    @attrs[key]
  end
end