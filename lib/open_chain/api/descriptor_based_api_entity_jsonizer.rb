require 'open_chain/api/api_entity_jsonizer'

module OpenChain; module Api; class DescriptorBasedApiEntityJsonizer < ApiEntityJsonizer

   protected

    def add_model_fields_to_hash user, parent_entity, parent_module, model_field_list, field_hash, module_root = true
      descriptor = parent_module.snapshot_descriptor
      raise "Missing snapshot_descriptor for #{parent_module.label}." if descriptor.nil?

      add_fields user, parent_entity, model_field_list, field_hash, descriptor, true

      nil
    end

    def build_model_field_hash user, core_module, requested_model_fields, hash = {}, module_root = true, include_all = false
      descriptor = core_module.snapshot_descriptor
      raise "Missing snapshot_descriptor for #{core_module.label}." if descriptor.nil?

      build_descriptor_based_model_field_hash user, descriptor, requested_model_fields, hash, include_all
    end

  private

    def build_descriptor_based_model_field_hash user, descriptor, requested_model_fields, hash = {}, include_all = false
      # We want to make sure we're not symbolizing the values sent in the requested_model_fields param
      # since this would open us up to a memory exhaustion DOS (since symbols aren't garbage collected)
      core_module = CoreModule.find_by_class_name(descriptor.entity_class.name)

      model_fields = core_module.every_model_field

      # Only include fields the user selected and are allowed to be accessed by the user
      hash[entity_hash_key(core_module)] = model_fields.keys.collect {|k| ((include_all || requested_model_fields.include?(k) || requested_model_fields.include?(k.to_s)) && model_fields[k].can_view?(user)) ? model_fields[k] : nil}.compact

      Array.wrap(descriptor.children).each do |child_descriptor|
        build_descriptor_based_model_field_hash user, child_descriptor, requested_model_fields, hash, include_all
      end

      hash
    end

    def add_fields user, parent, model_field_list, field_hash, descriptor, module_root = false
      # Add parent level fields...
      parent_core_module = core_module(parent)
      current_module_field_list = model_field_list[entity_hash_key(parent_core_module)]

      field_hash['id'] = parent.id

      Array.wrap(current_module_field_list).each do |mf|
        field_hash[mf.uid] = export_field(user, parent, mf)
      end

      Array.wrap(descriptor.children).each do |child_descriptor|
        child_hash_key = child_descriptor.parent_association
        child_module_values = []
        relation = parent.public_send(child_hash_key.to_sym)

        # Assumption here, if the association doesn't respond to :each, then it's a has_one or belongs_to relation, so there
        # is nothing to iterate over.
        if relation.respond_to?(:each)
          relation.each do |child|
            child_values = {}
            add_fields(user, child, model_field_list, child_values, child_descriptor)
            child_module_values << child_values unless child_values.blank?
          end
        else
          child_values = {}
          add_fields(user, child, model_field_list, child_values, child_descriptor)
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

    def core_module entity
      core_module_map[entity.class]
    end

    def core_module_map
      @@cm_map ||= cm_object_map = Hash[CoreModule.all.map {|cm| [cm.klass, cm] }]
      @@cm_map
    end

end; end; end
