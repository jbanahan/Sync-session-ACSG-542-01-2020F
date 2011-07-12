module OpenChain

  class FieldLogicValidator 
    def self.validate record, nested=false
      passed = true
      cm = CoreModule.find_by_class_name record.class.to_s
      #need more info on why we got records in here without appropriate core modules
      if cm.nil?
        begin
          raise "Core Module Not Found for class #{record.class.to_s}"
        rescue
          OpenMailer.send_generic_exception($!).deliver
        end
        return true
      end
      rules = FieldValidatorRule.find_cached_by_core_module cm
      rules.each do |rule|
        msg = rule.validate_field record, nested
        if !msg.empty?
          msg.each {|m| record.errors[:base] << m}
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
    attr_accessor :base_object

    def initialize(base_obj=nil)
      self.base_object = base_obj
    end

  end

end
