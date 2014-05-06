module OpenChain; module Api; class ApiEntityJsonizer

  # This method returns a JSON representation of the given entity.
  # The entity must be an active record representation of a core module object.
  # The model_field_uids should be an array of string representations of the model fields 
  # to include in the 
  def entity_to_json user, entity, model_field_uids
    core_module = CoreModule.find_by_class_name entity.class.to_s
    raise "CoreModule could not be found for class #{entity.class.to_s}." if core_module.nil?

    outer_hash = {}

    requested_model_fields = build_model_field_hash user, core_module, model_field_uids.to_set

    unless requested_model_fields.blank?
      entity_hash = {}
      outer_hash[entity_hash_key(core_module)] = entity_hash
      add_model_fields_to_hash user, entity, core_module, requested_model_fields, entity_hash
    end

    outer_hash.to_json
  end

  # Returns a full listing of the model fields that are accessible to the user for the given core module
  # and all its children.
  def model_field_list_to_json user, core_module
    model_field_hash = build_model_field_hash user, core_module, {}, {}, true, true

    outer = {}

    model_field_hash.keys.each do |k|
      inner = []
      model_field_hash[k].each do |mf|
        inner << build_model_field_descriptor(mf)
      end

      # Don't leak information on the entity levels to those who can't see any fields
      # at that level
      outer[k] = inner if inner.size > 0
    end
    outer.to_json
  end

  private 

    def build_model_field_descriptor mf
      {'uid'=>mf.uid.to_s, 'label' => mf.label(false), 'data_type' => mf.data_type.to_s}
    end

    def build_model_field_hash user, core_module, requested_model_fields, hash = {}, module_root = true, include_all = false
      # We want to make sure we're not symbolizing the values sent in the requested_model_fields param
      # since this would open us up to a memory exhaustion DOS (since symbols aren't garbage collected)

      # Purposefully NOT passing the user here since there's no need to validate access to every model field
      # since we're generally only accessing a small portion of them.  Individual model_field access is checked below.
      model_fields = core_module.model_fields

      fields = []

      # Only include fields the user selected and are allowed to be accessed by the user
      hash[entity_hash_key(core_module, module_root)] = model_fields.keys.collect {|k| ((include_all || requested_model_fields.include?(k) || requested_model_fields.include?(k.to_s)) && model_fields[k].can_view?(user)) ? model_fields[k] : nil}.compact

      # Now find all the child modules model fields
      core_module.children.each do |child_core_module|
        build_model_field_hash user, child_core_module, requested_model_fields, hash, false, include_all
      end

      hash
    end

    def add_model_fields_to_hash user, parent_entity, parent_module, model_field_list, field_hash, module_root = true
      parent_model_fields = parent_module.model_fields

      model_field_list[entity_hash_key(parent_module, module_root)].each do |mf|
        field_hash[mf.uid] = mf.process_export(parent_entity, user)
      end

      # Only include the id for the root entity.  There's not really much of a point in passing the child ids
      # back, especially since for all the main objects we end up destroying and rebuilding child records
      # which ends up changing their ids.
      field_hash['id'] = parent_entity.id if module_root

      parent_module.children.each do |child_module|
        child_hash_key = entity_hash_key(child_module, false)
        child_module_values = []
        parent_module.child_objects(child_module, parent_entity).each do |child_object|
          child_values = {}
          add_model_fields_to_hash user, child_object, child_module, model_field_list, child_values, false
          child_module_values << child_values unless child_values.blank?
        end
        field_hash[child_hash_key] = child_module_values unless child_module_values.blank?
      end

      nil
    end

    def entity_hash_key core_module, module_root = true
      module_name = core_module.class_name.underscore
      module_name = module_name.pluralize unless module_root

      module_name
    end
end; end; end
