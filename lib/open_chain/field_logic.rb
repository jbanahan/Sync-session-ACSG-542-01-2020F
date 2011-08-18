module OpenChain

  class CoreModuleProcessor

    def self.bulk_objects search_run_id, primary_keys, &block
      sr_id = search_run_id 
      if !sr_id.blank? && sr_id.match(/^[0-9]*$/)
        sr = SearchRun.find sr_id
        good_count = sr.total_objects
        sr.all_objects.each do |o|
          yield good_count, o
        end
      else
        pks = primary_keys 
        good_count = pks.size
        pks.values.each do |key|
          p = Product.find key
          yield good_count, p  
        end
      end
    end
    #save and validate a base_object representing a CoreModule like a product instance or a sales_order instance
    #this method will automatically save custom fields and will rollback if the validation fails
    #if you set the raise_exception parameter to true then the method will throw the OpenChain::FieldLogicValidator exception (useful for wrapping in a larger transaction)
    def self.validate_and_save_module base_object, parameters, succeed_lambda, fail_lambda, opts={}
      inner_opts = {:before_validate=>lambda {|obj|}}
      inner_opts.merge! opts
      begin
        base_object.transaction do 
          base_object.update_attributes!(parameters)
          customizable_parent_params = parameters["#{base_object.class.to_s.downcase}_cf"]
          OpenChain::CoreModuleProcessor.update_custom_fields base_object, customizable_parent_params
          inner_opts[:before_validate].call base_object
          OpenChain::FieldLogicValidator.validate!(base_object) 
          base_object.piece_sets.each {|p| p.create_forecasts} if base_object.respond_to?('piece_sets')
          base_object.class.find(base_object.id).create_snapshot if base_object.respond_to?('create_snapshot')
          succeed_lambda.call base_object
        end
      rescue OpenChain::ValidationLogicError
        fail_lambda.call base_object, base_object.errors
      rescue ActiveRecord::RecordInvalid
        if $!.record != base_object
          $!.record.errors.full_messages.each {|m| base_object.errors[:base]<<m}
        end
        fail_lambda.call base_object, base_object.errors
      end
    end

    #loads the custom values into the parent object without saving
    def self.set_custom_fields customizable_parent, cpp, &block
      pass = true
      unless cpp.nil?
        cpp.each do |k,v|
          definition_id = k.to_s
          cd = CustomDefinition.cached_find(definition_id)
          cv = customizable_parent.get_custom_value cd
          unless (v.blank? && cv.value.blank?) || v==cv.value
            cv.value = v
            yield cv if block_given?
          end
          pass = false unless cv.errors.empty?
          cv.errors.full_messages.each {|m| customizable_parent.errors[:base] << m} 
        end
      end
      pass
    end

    def self.update_custom_fields customizable_parent, customizable_parent_params 
      set_custom_fields(customizable_parent, customizable_parent_params) {|cv| cv.save!}
    end

    def self.update_status(statusable)
      current_status = statusable.status_rule_id
      statusable.set_status
      statusable.save if current_status!=statusable.status_rule_id
    end
  end

  class FieldLogicValidator 
    def self.validate record, nested=false
      passed = true
      cm = CoreModule.find_by_class_name record.class.to_s
      #need more info on why we got records in here without appropriate core modules
      if cm.nil?
        begin
          raise "Core Module Not Found for class #{record.class.to_s}"
        rescue
          $!.log_me
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
