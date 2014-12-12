module UpdateModelFieldsSupport
  extend ActiveSupport::Concern

  # Basically, this is a replacement for ActiveRecord::Base.update_attributes where 
  # the keys are model field uids and the values are all set via the model field process_import
  # methods.
  #
  # If any process_import errors occur (at any heirarchical level), error messages are added
  # to the errors[:base] of the root parent object passed to this method.
  #
  # Method returns true if all values imported correctly, false if any errors were encountered.
  #
  # The only real difference is that any hash intended to create a new nested object (.ie classification / tariff)
  # MUST ALWAYS include the model field uid indicated by the CoreModule#key_attribute_field_uid method
  # for the core module being created.
  # 
  # For example, if when updating a product, your child hash doesn't include an 'id' key for a classification, then it MUST
  # include the 'class_cntry_id' field/value in order to generate a new classification under the product.
  #
  # Options:
  # user: if present, uses given user, otherwise uses the value currently set in User.current
  # set_last_updated_by: if true (default), the last_updated_by attribute of this object is set to the user.  If false, last_updated_by is not set
  # exclude_blank_values: if true (false by default), any values from the hash that evaluate to blank? will be skipped.  This includes both custom and 
  # and "standard" model field values.
  # exclude_custom_fields: if true (false by default), any values related to custom fields will be ignored.
  def update_model_field_attributes object_parameters, opts = {}
    opts = {user: User.current}.merge opts
    opts[:no_validation] = false
    with_transaction_returning_status do
      __assign_model_field_attributes object_parameters, opts
      # save clears the number of errors..but we want all the errors that may have been
      # encountered via save to be included if save should raise an error...so try save
      # and if it doesn't error...then we'll raise our own error
      pre_save_errors = errors[:base].clone
      save_val = self.save

      # validate that save was ok...we consider it not ok if we had our own model field errors
      if pre_save_errors.size > 0
        errors[:base].push *pre_save_errors
      end

      save_val && pre_save_errors.size == 0
    end
  end

  # See #update_model_field_attributes
  #
  # This method (like the standard update_attributes!) raises an error if 
  # any save issues occur.
  def update_model_field_attributes! object_parameters, opts = {}
    opts = {user: User.current}.merge opts
    opts[:no_validation] = false
    with_transaction_returning_status do
      __assign_model_field_attributes object_parameters, opts
      # save! clears the number of errors..but we want all the errors that may have been
      # encountered via save to be included if save should raise an error...so try save
      # and if it doesn't error...then we'll raise our own error
      pre_save_errors = errors[:base].clone
      begin
        save_val = self.save!
      rescue ActiveRecord::RecordInvalid => e
        # save! blows away any errors we had prior to starting..add them back in
        e.record.errors[:base].push *pre_save_errors if pre_save_errors.size > 0
        raise e
      end
      
      # save! won't actually raise validation errors caused from our 
      # model assignments, so raise manually here if there are any errors[:base] messages
      if pre_save_errors.size > 0
        errors[:base].push *pre_save_errors
        raise ActiveRecord::RecordInvalid.new(self)
      end

      save_val
    end
  end

  # See #update_model_field_attributes.
  #
  # This method (like the standard assign_attributes) simply sets all values
  # into the object. It does check the validity of the values, however, returning
  # true if the object is valid and returning false if nota and populating the errors object.
  #
  # If there are model field import errors, they will be represented in the objects errors.
  # NOTE: ActiveRecord validations are NOT run.
  #
  # opts
  # no_validation: if true, no validation of the attributes will be done...meaning no errors
  # will be recorded when assigning attributes
  def assign_model_field_attributes object_parameters, opts = {}
    opts = {user: User.current}.merge opts
    __assign_model_field_attributes object_parameters, opts

    unless opts[:no_validation] === true
      pre_valid_errors = errors[:base].clone
      valid = self.valid?

      errors[:base].push *pre_valid_errors if pre_valid_errors.size > 0
      valid && pre_valid_errors.size == 0
    else
      true
    end
  end

  private 

    # Basically, this is a replacement for ActiveRecord::Base.assign_attributes where 
    # the keys are model field uids and the values are all set via the model field process_import
    # methods.
    #
    # The object HAS NOT been saved after completion of this method, hence the comparison to the
    # assign_attributes ActiveRecord method and not update_attributes.  
    #
    # If any process_import errors occur (at any heirarchical level), error messages are added
    # to the errors[:base] of the root parent object passed to this method.
    #
    # Method returns true if all values imported correctly, false if any errors were encountered.
    def __assign_model_field_attributes object_parameters, opts = {}
      opts = {user: User.current, set_last_updated_by: true}.merge opts

      # Basically, what we're doing here is stripping out all the non-key model field uids
      # from the hash, turning the uids into their corresponding field name, 
      # then running assign_attributes so that it will create new objects, destroy 
      # ones marked for deletion..all the good stuff that rails gives us automatically.

      # After that, we're going through the core module heirarchy and using model field
      # process import to import every object parameter
      base_object = self
      user = opts[:user]

      # The reason why we're making multiple copies here is because Rails 3.x has issues
      # with deep_dup not cloning Array keys...so if the params are like 'val' => [{'id' => 'blah'}]
      # we can end up having key values stripped if we clone off the model_field_param after 
      # removing blank keys...annoying, but it's not that much extra CPU usage to just traverse
      # the params twice.
      model_field_params = object_parameters.deep_dup.with_indifferent_access
      update_params = object_parameters.deep_dup.with_indifferent_access

      if opts[:exclude_blank_values] === true
        model_field_params = remove_blank_values model_field_params
        update_params = remove_blank_values update_params
      end
      update_params = clean_params_for_attribute_assignment update_params, model_field_params, self

      base_object.assign_attributes update_params

      process_import_parameters base_object, model_field_params, base_object, user, opts

      if opts[:set_last_updated_by] && base_object.respond_to?(:last_updated_by=)
        base_object.last_updated_by = user
      end

      nil
    end

    def process_import_parameters root_object, object_parameters, base_object, user, opts = {}
      # Don't load anything into objects that have parameters showing it as marked for deletion
      return if ['1', 'true', true].include? object_parameters['_destroy']

      data = core_module_info base_object
      model_fields = data[:model_fields].select {|uid, mf| mf.can_view? user}

      child_core_module = data[:child_core_module]
      child_association_key = data[:child_association_key]

      object_parameters.each_pair do |name, value|
        next if name == "id"

        # The following handles both the following value rails nested attribute styles:
        # {'child_attributes' => {'0' => {'attribute_1' => 'value'}}}
        # {'child_attributes' => [{'attribute_1' => 'value'}]}
        if (value.respond_to?(:each)) && child_association_key && name == child_association_key
          if value.respond_to?(:each_pair)
            value.each_pair do |child_index, child_hash|
              child_object = locate_child_object(base_object, child_core_module, child_hash, user)
              process_import_parameters(root_object, child_hash, child_object, user, opts) if child_object && !child_object.destroyed? && !child_object.marked_for_destruction?
            end
          else
            value.each do |child_hash|
              child_object = locate_child_object(base_object, child_core_module, child_hash, user)
              process_import_parameters(root_object, child_hash, child_object, user, opts) if child_object && !child_object.destroyed? && !child_object.marked_for_destruction?
            end
          end
        else
          mf = model_fields[name.to_sym]
          next if mf.nil? || mf.blank? || (opts[:exclude_custom_fields] === true && mf.custom?)
          
          result = mf.process_import base_object, value, user
          root_object.errors[:base] = result if result.error? && opts[:no_validation] != true
        end
      end
    end

    def locate_child_object parent_object, child_core_module, child_parameters, user
      children = child_objects(parent_object, child_core_module)

      if child_parameters['id'] && (child_id = child_parameters['id'].to_i) != 0
        return children.find {|c| c.id == child_id}
      elsif !(key_param = child_parameters[:virtual_identifier]).blank?
        # Don't bother with field validation at this point (plus, I don't really see any scenario occurring 
        # where the user doesn't have access to at least view a key field)
        # Make sure we're also not returning a field w/ an id already set, since then an id param should 
        # have been set in the data already
        return children.find {|c| (c.id.nil? || c.id == 0) && c.virtual_identifier == key_param}
      end

      nil
    end

    def clean_params_for_attribute_assignment params, model_field_params, core_module, parent = true
      data = core_module_info core_module

      # In this case, we do actually want all the model fields...we want there to be an error when the
      # user attempts to import a field they don't have access to...rather than silently ignoring it.
      model_fields = data[:model_fields]
      child_core_module = data[:child_core_module]
      child_association_key = data[:child_association_key]

      id_found = false
      params.each_pair do |name, value|
        # Don't delete the fields rails needs to identify the objects and their child associations
        if ["id", "_destroy"].include? name
          id_found = true if name == "id"
          next
        end

        # The following handles both the following value rails nested attribute styles:
        # {'child_attributes' => {'0' => {'attribute_1' => 'value'}}}
        # {'child_attributes' => [{'attribute_1' => 'value'}]}
        if (value.respond_to?(:each)) && child_association_key && name == child_association_key
          if value.respond_to?(:each_pair)
            value.each_pair do |child_index, child_hash|
              if child_hash.is_a?(Hash)
                child_original_params = model_field_params[name][child_index]
                clean_params_for_attribute_assignment(child_hash, child_original_params, child_core_module, false) 
              end
            end
          else
            value.each_with_index do |child_hash, idx|
              child_original_params = model_field_params[name][idx]
              clean_params_for_attribute_assignment(child_hash, child_original_params, child_core_module, false) if child_hash.is_a?(Hash)
            end
          end
        else
          # Delete all non-identifier values from this hash, which will eventually be passed to ActiveRecord::Base#assign_attributes
          params.delete name
        end
      end

      # We don't need to add an id to the outermost layer..for the most part, this isn't an issue, but 
      # it becomes one when you add this module onto a non-CoreModule.
      if !parent && !id_found
        # What we're doing here is adding in an identifier when no 'id' key was found (which when Rails
        # itself parses the hash eventually should result in it creating a new object, setting the virtual_identifer).
        # This allows us later when we're doing the process_import step on the new object to be able to find
        # it by the virtual_identifier value in the parent object (rather than trying to find it by some natural key
        # or something like that)

        # The actual virtual_identifier field is created via the CoreModule (it adds it to all classes set up as a core module)
        t = Time.now
        params[:virtual_identifier] = "#{t.to_i}.#{t.nsec}"
        model_field_params[:virtual_identifier] = params[:virtual_identifier]
      end

      params
    end

    def remove_blank_values params
      params.each_pair do |k, v|
        if v.respond_to?(:each)
          vals = v.respond_to?(:values) ? v.values : v.each
          vals.each {|child_hash| remove_blank_values child_hash}
        else
          params.delete k if blank_value? v
        end
      end

      params
    end

    def blank_value? value
      return true if value.nil?

      if value.respond_to? :blank?
        value.blank?
      else
        value.to_s.blank?
      end
    end

    # This method exist largely as extension points to shoe-horn this update attributes stuff onto 
    # base objects that are not core modules, but have core module children (See InstantClassification)
    def core_module_info object_or_core_module
      core_module = nil
      if object_or_core_module.is_a? CoreModule
        core_module = object_or_core_module
      else
        core_module = CoreModule.find_by_object(object_or_core_module)
      end
      
      model_fields = core_module.every_model_field

      child_core_module = core_module.children.first
      child_association_key = child_core_module ? "#{core_module.child_association_name(child_core_module)}_attributes" : nil

      {model_fields: model_fields, child_core_module: child_core_module, child_association_key: child_association_key}
    end

    # This method exists largely as extension points to shoe-horn this update attributes stuff onto 
    # base objects that are not core modules, but have core module children (See InstantClassification)
    def child_objects parent_object, child_core_module
      parent_core_module = CoreModule.find_by_object parent_object
      parent_core_module.child_objects(child_core_module, parent_object)
    end
    
end