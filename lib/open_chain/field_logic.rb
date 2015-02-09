module OpenChain

  class CoreModuleProcessor

    def self.bulk_objects core_module, search_run_id, primary_keys, &block
      sr_id = search_run_id 
      if !sr_id.blank? && sr_id.to_s.match(/^[0-9]*$/)
        sr = SearchRun.find sr_id
        good_count = sr.total_objects
        sr.find_all_object_keys do |k|
          yield good_count, core_module.find(k)
        end
      else
        pks = primary_keys.respond_to?(:values) ? primary_keys.values : primary_keys
        good_count = pks.size
        pks.each do |key|
          p = core_module.find key
          yield good_count, p  
        end
      end
    end

    #save and validate a base_object representing a CoreModule like a product instance or a sales_order instance
    #this method will automatically save custom fields and will rollback if the validation fails
    #if you set the raise_exception parameter to true then the method will throw the OpenChain::FieldLogicValidator exception (useful for wrapping in a larger transaction)
    def self.validate_and_save_module all_params, base_object, object_parameters, user, succeed_lambda, fail_lambda, opts={}
      inner_opts = {:before_validate=>lambda {|obj|}, :parse_custom_fields=>true}
      inner_opts.merge! opts
      update_model_field_opts = {exclude_blank_values: opts[:exclude_blank_values], exclude_custom_fields: (opts[:parse_custom_fields] === false), user: user}
      begin
        base_object.transaction do
          # This saves all standard model attributes and custom values from the passed in object parameters
          base_object.update_model_field_attributes! object_parameters, update_model_field_opts
          inner_opts[:before_validate].call base_object
          raise OpenChain::ValidationLogicError unless CoreModule.find_by_object(base_object).validate_business_logic base_object
          OpenChain::FieldLogicValidator.validate!(base_object) 
          base_object.piece_sets.each {|p| p.create_forecasts} if base_object.respond_to?('piece_sets')
          snapshot = base_object.class.find(base_object.id).create_snapshot if base_object.respond_to?('create_snapshot')

          if succeed_lambda
            if snapshot && succeed_lambda.parameters.count > 1
              succeed_lambda.call base_object, snapshot
            else
              succeed_lambda.call base_object
            end
          end
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
    def self.set_custom_fields customizable_parent, cpp, user, &block
      pass = true
      unless cpp.nil?
        cpp.each do |k,v|
          custom_def = CustomDefinition.cached_find(k.to_s)
          model_field  = custom_def.model_field
          next if model_field.blank? || model_field.read_only?

          cv = customizable_parent.get_custom_value custom_def
          if !model_field.can_edit? user
            cv.errors[:base] << "You do not have permission to edit #{mf.label}."
          elsif v != cv.value && !(v.blank? && cv.value.blank?)
            model_field.process_import customizable_parent, v, user
            yield cv if block_given?
          end

          if !cv.errors.empty?
            pass = false
            cv.errors.full_messages.each {|m| customizable_parent.errors[:base] << m} 
          end
        end
      end
      pass
    end

    def self.update_custom_fields customizable_parent, customizable_parent_params, user 
      set_custom_fields(customizable_parent, customizable_parent_params, user) {|cv| cv.save!}
    end

    def self.update_status(statusable)
      current_status = statusable.status_rule_id
      statusable.set_status
      statusable.save if current_status!=statusable.status_rule_id
    end
  end

  class FieldLogicValidator 
    def self.validate record, nested=false, skip_read_only=false
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
        # The readonly skip is basically for cases where you've already done ModelField#process_imports
        # and are just checking any other field validations.  Since process_import already enforces
        # the readonly rule, we can skip these here if instructed.
        next if skip_read_only && rule.readonly?
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
    def self.validate! record, nested=false, skip_read_only=false
      raise ValidationLogicError.new(nil, record) unless validate record, nested, skip_read_only
    end
  end


  class ValidationLogicError < StandardError
    attr_accessor :base_object

    def initialize(msg = nil, base_obj=nil)
      super(msg)
      self.base_object = base_obj
    end

  end

end
