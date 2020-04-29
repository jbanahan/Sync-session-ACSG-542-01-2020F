module OpenChain; module Api; class ApiEntityJsonizer

  def initialize output_opts = {}
    @output_opts = {blank_if_nil: false, force_big_decimal_numeric: false}.merge output_opts
  end

  # This method returns a JSON representation of the given entity.
  # The entity must be an active record representation of a core module object.
  # The model_field_uids should be an array of string representations of the model fields
  # to include in the
  def entity_to_json user, entity, model_field_uids
    outer_hash = {}
    entity_hash = entity_to_hash user, entity, model_field_uids
    core_module = CoreModule.find_by_class_name entity.class.to_s
    outer_hash[entity_hash_key(core_module)] = entity_hash unless entity_hash.blank?
    outer_hash.to_json
  end

  # This method returns a JSON representation of the given entity.
  # The entity must be an active record representation of a core module object.
  # The model_field_uids should be an array of string representations of the model fields
  # to include in the
  def entity_to_hash user, entity, model_field_uids
    core_module = CoreModule.find_by_class_name entity.class.to_s
    raise "CoreModule could not be found for class #{entity.class.to_s}." if core_module.nil?

    requested_model_fields = build_model_field_hash user, core_module, model_field_uids.to_set
    entity_hash = {}
    unless requested_model_fields.blank?
      add_model_fields_to_hash user, entity, core_module, requested_model_fields, entity_hash
    end

    entity_hash
  end

  # Returns a full listing of the model fields that are accessible to the user for the given core module
  # and all its children.
  def model_field_list_to_json user, core_module
    model_field_hash = build_model_field_hash user, core_module, {}, {}, true, true

    outer = {}

    model_field_hash.each_key do |k|
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

  def export_field user, object, model_field
    v = model_field.process_export object, user

    if v.nil?
      v = "" if @output_opts[:blank_if_nil] == true
    else
      case model_field.data_type
      when :integer
        v = v.to_i
      when :decimal, :numeric
        v = BigDecimal(v)

        # The below call (to_f) can result in loss of precision because of the translation to
        # float.  This is done though, so that the value is serialized over the wire
        # as a javascript numeric instead of a string (as BigDecimal is serialized as).
        # Be very careful if you are expecting precision for amounts w/ a even a relatively low
        # number of significant digits (or decimal places)
        # VERY STRONGLY consider using the BigNumber javascript library on the client side
        # instead of forcing to numeric for these values.
        v = @output_opts[:force_big_decimal_numeric] == true ? v.to_f : v
      when :datetime
        v = v.in_time_zone(user.time_zone) if user.time_zone
      end
    end

    v
  end

  protected

    def build_model_field_descriptor mf
      {'uid'=>mf.uid.to_s, 'label' => mf.label(false), 'data_type' => mf.data_type.to_s}
    end

    def build_model_field_hash user, core_module, requested_model_fields, hash = {}, module_root = true, include_all = false
      # We want to make sure we're not symbolizing the values sent in the requested_model_fields param
      # since this would open us up to a memory exhaustion DOS (since symbols aren't garbage collected)

      model_fields = core_module.every_model_field

      # Only include fields the user selected and are allowed to be accessed by the user
      hash[entity_hash_key(core_module)] = model_fields.keys.collect {|k| ((include_all || requested_model_fields.include?(k) || requested_model_fields.include?(k.to_s)) && model_fields[k].can_view?(user)) ? model_fields[k] : nil}.compact

      # Now find all the child modules model fields
      core_module.children.each do |child_core_module|
        build_model_field_hash user, child_core_module, requested_model_fields, hash, false, include_all
      end

      hash
    end

    def add_model_fields_to_hash user, parent_entity, parent_module, model_field_list, field_hash, module_root = true
      current_module_field_list = model_field_list[entity_hash_key(parent_module)]

      field_hash['id'] = parent_entity.id

      current_module_field_list.each do |mf|
        field_hash[mf.uid] = export_field(user, parent_entity, mf)
      end

      parent_module.children.each do |child_module|
        child_hash_key = entity_hash_key(child_module, parent_module)
        child_module_values = []
        parent_module.child_objects(child_module, parent_entity).each do |child_object|
          child_values = {}
          add_model_fields_to_hash user, child_object, child_module, model_field_list, child_values, false
          child_module_values << child_values unless child_values.blank?
        end
        field_hash[child_hash_key] = child_module_values unless child_module_values.blank?
      end

      # Remove the id from the hash if there were no fields requested at or below this current object level.
      # In other words, don't send tariff level nested id data if the user only requests product header fields.
      # There's a chance for optimization here by not even bothering to recurse down to module levels that don't
      # have fields, but for now this works.
      field_hash.delete('id') if !module_root && field_hash.size == 1 && current_module_field_list.size == 0

      nil
    end

    def entity_hash_key core_module, parent_module = nil
      if parent_module
        parent_module.child_association_name(core_module)
      else
        core_module.class_name.underscore
      end
    end
end; end; end
