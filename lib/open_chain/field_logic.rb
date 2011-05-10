module OpenChain

  class FieldLogicValidator 
    def self.validate record, nested=false
      passed = true
      cm = CoreModule.find_by_class_name record.class.to_s
      rules = FieldValidatorRule.find_cached_by_core_module cm
      rules.each do |rule|
        msg = rule.validate_field record, nested
        if msg
          record.errors[:base] << msg
          passed = false
        end
      end
      cm.children.each do |child_module|
        child_records = cm.child_objects child_module, record
        child_records.each do |cr|
          if !validate(cr,true)
            cr.errors[:base].each {|m| record.errors[:base] << m}
            passed = false
          end
        end
      end
      return passed
    end
    def self.validate! record
      raise ValidationLogicError unless validate record
    end
  end


  class ValidationLogicError < StandardError

  end

end
