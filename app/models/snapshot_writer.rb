class SnapshotWriter

  def entity_json descriptor, entity
    json_hash = hash_for_entity(descriptor, entity)
    ActiveSupport::JSON.encode json_hash
  end

  protected 
  
    def hash_for_entity entity_descriptor, entity
      core_module = core_module_for_entity(entity)
      byebug if core_module.nil?
      base_hash = {'entity'=> write_core_entity_fields(core_module, entity)}
      
      children = hash_for_entity_children(entity_descriptor.children, entity)
      base_hash['entity']['children'] = children if children.length > 0

      base_hash
    end

    def write_entity_model_fields core_module, entity
      model_fields = {}
      core_module.model_fields {|mf| !mf.history_ignore? }.values.each do |mf|
        v = mf.process_export entity, nil, true
        model_fields[mf.uid] = v unless v.nil?
      end
      model_fields
    end

    def hash_for_entity_children child_descriptors, entity
      children = []
      Array.wrap(child_descriptors).each do |child_descriptor|
        association_name = child_descriptor.parent_association
        raise "No association name found for #{entity.class.name} class' child #{child_descriptor.entity_class.name}." if association_name.blank?
        raise "No association named #{association_name} found in #{entity.class.name}." unless entity.respond_to?(association_name.to_sym)

        relation = entity.public_send(association_name.to_sym)

        # Assumption here, if the association doesn't respond to :each, then it's a has_one or belongs_to relation, so there
        # is nothing to iterate over.
        if relation.respond_to?(:each)
          relation.each do |child|
            child_hash = hash_for_entity(child_descriptor, child)
            children << child_hash unless child_hash.blank?
          end
        else
          child_hash = hash_for_entity(child_descriptor, relation)
          children << child_hash unless child_hash.blank?
        end
      end

      children
    end

    def write_core_entity_fields core_module, entity
      {'core_module'=> core_module.class_name,'record_id'=>entity.id, 'model_fields'=>write_entity_model_fields(core_module, entity)}
    end

    def core_module_for_entity entity
      core_module_map[entity.class]
    end

    private
      def core_module_map
        @@cm_map ||= cm_object_map = Hash[CoreModule.all.map {|cm| [cm.klass, cm] }]
        @@cm_map
      end
end