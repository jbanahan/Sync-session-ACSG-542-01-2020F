module ValidatesFieldFormat

  def validate_field_format obj, opt = {}
    opt = {yield_matches: false, yield_failures: true}.merge opt

    tested = 0
    messages = []
    validation_expressions.each_pair do |model_field, attrs|
      val = model_field.process_export(obj,nil,true)
      reg = attrs['regex']
      #If this option is used, any block will have to check this attribute and adjust message accordingly
      fail_if_matches = attrs['fail_if_matches'] 
      fail = fail_if_matches ? val.to_s.match(reg) : !val.to_s.match(reg)
      allow_blank = attrs['allow_blank'].to_s.to_boolean

      unless allow_blank && val.blank?
        if fail
          if opt[:yield_failures] && block_given?
            messages << yield(model_field, val, reg, fail_if_matches)
          else
            messages << (fail_if_matches ? "#{model_field.label} must NOT match '#{reg}' format." : "#{model_field.label} must match '#{reg}' format but was '#{val}'.")
          end
        elsif opt[:yield_matches] && block_given?
          yield(model_field, val, reg, fail_if_matches)
        end
      end
      tested += 1
    end

    messages.delete_if(&:blank?).join("\n").presence if tested == messages.count
  end

  def validation_expressions
    unless defined?(@expressions)
      @expressions = {}
      if rule_attribute('model_field_uid')
        attrs = {}
        @expressions[ModelField.find_by_uid(rule_attribute('model_field_uid'))] = attrs
        attrs['regex'] = rule_attribute('regex')
        attrs['fail_if_matches'] = rule_attribute('fail_if_matches')
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