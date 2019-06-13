require 'open_chain/s3'

module OpenChain
  class CoreModuleProcessor

    def self.bulk_objects core_module, primary_keys: nil, primary_key_file_bucket: nil, primary_key_file_path: nil, &blk
      if !primary_keys.blank?
        bulk_objects_from_array_or_hash(core_module, primary_keys, &blk)
      elsif !primary_key_file_bucket.nil? && !primary_key_file_path.nil?
        bulk_objects_from_s3_file(core_module, primary_key_file_bucket, primary_key_file_path, &blk)
      end
    end

    def self.bulk_objects_from_array_or_hash core_module, primary_keys, &blk
      pks = primary_keys.respond_to?(:values) ? primary_keys.values : primary_keys
      good_count = pks.size
      pks.each do |key|
        find_and_lock_object(core_module, good_count, key, &blk)
      end
    end
    private_class_method :bulk_objects_from_array_or_hash

    def self.bulk_objects_from_s3_file core_module, bucket, path, &blk
      # We're going to download the tempfile, read it as a json object, then pass it through to the bulk objects from array method
      OpenChain::S3.download_to_tempfile(bucket, path) do |temp|
        primary_keys = ActiveSupport::JSON.decode temp.read
        bulk_objects_from_array_or_hash(core_module, primary_keys, &blk)
      end
    end
    private_class_method :bulk_objects_from_s3_file

    def self.find_and_lock_object core_module, number_of_keys, key
      obj = core_module.find(key)
      # Don't yield directly in an open transaction...there's some code paths where a transaction
      # doesn't need to be run and it's pointless to open one when not needed.
      Lock.acquire(lock_name(core_module, obj), times: 5, yield_in_transaction: false) do
        yield number_of_keys, obj
      end
    end
    private_class_method :find_and_lock_object

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

          if !base_object.respond_to?(:inactive) || !base_object.inactive
            raise OpenChain::ValidationLogicError unless CoreModule.find_by_object(base_object).validate_business_logic base_object
            OpenChain::FieldLogicValidator.validate!(base_object) 
          end

          base_object.piece_sets.each {|p| p.create_forecasts} if base_object.respond_to?('piece_sets')
          
          base_object.update_attributes(:last_updated_by_id=>user.id) if base_object.respond_to?(:last_updated_by_id)
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

    def self.lock_name core_module, object
      # All the root core modules have a single key module field..so there's no point
      # in writing a loop here
      mfuid = core_module.key_model_field_uids.first
      mf = ModelField.find_by_uid mfuid

      # Make sure this lock name is identical to the one used in file import processing.

      # Disable any per-user security here by passing nil for user...Since this is just a
      # lock name on the backend there's no need for screening the object's value for it.
      "#{core_module.class_name}-#{mf.process_export(object, nil, true).to_s}"
    end
    private_class_method :lock_name
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
