module ValidatesFieldFormat
  extend ActiveSupport::Concern
  include FieldValidationHelper

  def validate_field_format obj, opt = {}
    opt = {yield_matches: false, yield_failures: true}.merge opt
    tested = 0
    messages = []
    validation_expressions(['regex', 'operator', 'value', 'secondary_model_field_uid', 'fail_if_matches', 'allow_blank']).each_pair do |model_field, attrs|
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

      #left operand
      if ['eqfdec', 'nqfdec', 'gtfdec', 'ltfdec'].include? attrs['operator']
        field_1 = model_field.process_export(obj, nil, true)
        field_2 = attrs['secondary_model_field'].process_export(obj, nil, true)
        val = (((field_1 - field_2) / field_2).abs) * 100
      elsif ['eq', 'nq', 'gt', 'lt'].include? attrs['operator']
        # To make this code simpler, we act as if we are getting actual numbers vs a field.
        val = model_field.process_export(obj,nil,true)
        second_field = ModelField.find_by_uid(attrs['value'])
        # We want reg to sync up with value, for the error message
        # we also want to use the exported value if second_field is indeed a model field.
        # All of this needs to be renamed, but that is a discussion for another day.
        reg = attrs['value'] = second_field.blank? ? attrs['value'] : second_field.process_export(obj,nil,true)
      else
        val = model_field.process_export(obj,nil,true)
      end
      if attrs['regex']
        reg ||= attrs['regex']
      else
        reg ||= attrs['value']
      end
      cc_hash = {"model_field_uid" => model_field.uid.to_s,  "value" => reg}
      cc_hash['operator'] = attrs['regex'].present? ? 'regexp' : attrs['operator']
      if attrs["secondary_model_field"].present?
        cc_hash["secondary_model_field_uid"] = attrs["secondary_model_field"].uid.to_s
      end
      sc = condition_criterion(cc_hash)
      op_label = CriterionOperator::OPERATORS.find{ |op| op.key == cc_hash["operator"]}.label.downcase
      #If this option is used, any block will have to check this attribute and adjust message accordingly
      fail_if_matches = attrs['fail_if_matches']
      fail = fail_if_matches ? sc.test?(obj, nil) : !sc.test?(obj, nil)
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
end