module ValidatesFieldFormat

  def validate_field_format obj, opt = {}
    opt = {yield_matches: false, yield_failures: true}.merge opt

    tested = 0
    messages = []
    validation_expressions.each_pair do |model_field, attrs|
      # If we have "if criterions", we don't evaluate the rule unless all the IF statements pass
      passed = true
      Array.wrap(attrs['if_criterions']).each do |sc|
        passed = sc.test?(obj)
        break unless passed
      end
      next unless passed

      # If we have 'unless_criterions', we don't evaluate the rule if any of statements pass
      passed = true
      Array.wrap(attrs['unless_criterions']).each do |sc|
        passed = !sc.test?(obj)
        break unless passed
      end
      next unless passed

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

        Array.wrap(rule_attribute('if')).each do |condition|
          attrs['if_criterions'] ||= []
          attrs['if_criterions'] << condition_criterion(condition)
        end
        Array.wrap(rule_attribute('unless')).each do |condition|
          attrs['unless_criterions'] ||= []
          attrs['unless_criterions'] << condition_criterion(condition)
        end
      else
        self.rule_attributes.each_pair do |uid, attrs|
          @expressions[ModelField.find_by_uid(uid)] = attrs

          conditions = attrs.delete 'if'
          Array.wrap(conditions).each do |condition|
            attrs['if_criterions'] ||= []
            attrs['if_criterions'] << condition_criterion(condition)
          end

          conditions = attrs.delete 'unless'
          Array.wrap(conditions).each do |condition|
            attrs['unless_criterions'] ||= []
            attrs['unless_criterions'] << condition_criterion(condition)
          end

        end
      end
    end

    @expressions
  end

  def rule_attribute key
    @attrs ||= self.rule_attributes
    @attrs[key]
  end

  def condition_criterion condition_json
    model_field = ModelField.find_by_uid(condition_json["model_field_uid"])
    raise "Invalid model field '#{condition_json["model_field_uid"]}' given in condition." unless model_field
    operator = condition_json["operator"]
    raise "No operator given in condition." if operator.blank?

    c = SearchCriterion.new
    c.model_field_uid = model_field.uid
    c.operator = operator
    c.value = condition_json["value"]

    c
  end
end