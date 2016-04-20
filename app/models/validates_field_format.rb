module ValidatesFieldFormat

  def validate_field_format obj, opt = {}
    opt = {yield_matches: false, yield_failures: true}.merge opt

    messages = []
    validation_expressions.each_pair do |model_field, attrs|
      
      # Memoize the attributes and model field, there's no need to have to deserialze them and do the model field lookup repeatedly
      # for any rule that runs over child objects. These values shouldn't change over the validation lifespan of the rule.
      val = model_field.process_export(obj,nil,true)
      reg = attrs['regex']
      allow_blank = attrs['allow_blank'].to_s.to_boolean

      unless allow_blank && val.blank?
        if !val.to_s.match(reg)
          if opt[:yield_failures] && block_given?
            messages << yield(model_field, val, reg)
          else
            messages << "#{model_field.label} must match '#{reg}' format, but was '#{val}'"      
          end
        elsif opt[:yield_matches] && block_given?
          yield model_field, val, reg
        end
      end
    end

    messages.join("\n").presence if rule_attribute('model_field_uid') || self.rule_attributes.count == messages.count
  end

  def validation_expressions
    unless defined?(@expressions)
      @expressions = {}
      if rule_attribute('model_field_uid')
        attrs = {}
        @expressions[ModelField.find_by_uid(rule_attribute('model_field_uid'))] = attrs
        attrs['regex'] = rule_attribute('regex')
        attrs['allow_blank'] = rule_attribute('allow_blank')
      else
        self.rule_attributes.each_pair do |uid, attrs|
          @expressions[ModelField.find_by_uid(uid)] = attrs
        end
      end
    end

    @expressions
  end

  def rule_attribute key
    @attrs ||= self.rule_attributes
    @attrs[key]
  end
end