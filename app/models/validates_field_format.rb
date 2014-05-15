module ValidatesFieldFormat

  def validate_field_format obj
    # Memoize the attributes and model field, there's no need to have to deserialze them and do the model field lookup repeatedly
    # for any rule that runs over child objects. These values shouldn't change over the validation lifespan of the rule.
    @attrs ||= self.rule_attributes
    @model_field ||= ModelField.find_by_uid @attrs['model_field_uid']
    val = @model_field.process_export(obj,nil,true)
    reg = @attrs['regex']

    message = nil
    unless @attrs['allow_blank'] && val.blank?
      if !val.to_s.match(reg)
        if block_given?
          message = yield @model_field, val, reg
        else
          message = "#{@model_field.label} must match '#{reg}' format, but was '#{val}'"      
        end
      end
    end
    
    message
  end
end