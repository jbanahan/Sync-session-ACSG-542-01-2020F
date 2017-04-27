class SnapshotWriter

  def entity_json descriptor, entity
    json_hash = hash_for_entity(descriptor, entity)
    ActiveSupport::JSON.encode json_hash
  end

  # This method is for those that want to be able to get at the actual value the snapshot writer
  # utilizes when generating a snapshot.  This can be handy if you need to compare an object to
  # a snapshot.  In which case, you should use the json_string option, which will return the 
  # exact field value you'd expect to get when reading data out of a hashified snapshot json string.
  def self.field_value entity, model_field, json_string: false
    value = model_field.process_export entity, nil, true

    # For Timestamps we always want to store off the value adjusted to UTC (just like the database)
    if value.respond_to?(:in_time_zone)
      value = value.in_time_zone("UTC")
    end

    # Null values are not added to the snapshot, so return these as null here too
    if !value.nil? && json_string
      # All JSONized values are returned with quotes around them except null or booleans.
      # What we're after is the string value, sans quotes.  This is primarily to 
      # allow us to take an entity's current state and see if it matches against what's
      # in a snapshot.

      # "Test".to_json -> '"Test"'
      # 1.to_json -> '1'
      # 1.0.to_json -> '1.0'
      # BigDecimal("1.0").to_json -> '"1.0"'
      # Date.new(2017,2,1).to_json -> '"2017-02-01"'
      # true.to_json -> "true"
      value = value.to_json
      if ![:boolean, :integer].include? model_field.data_type
        value = value[1..-2]
      end
    end

    value
  end

  # This method is for those that want to be able to get at the actual value the snapshot writer
  # utilizes when generating a snapshot.  This can be handy if you need to compare an object to
  # a snapshot.  In which case, you should use the json_string option, which will return the 
  # exact field value you'd expect to get when reading data out of a hashified snapshot json string.
  def field_value entity, model_field, json_string: false
    self.class.field_value entity, model_field, json_string: json_string
  end

  protected 
  
    def hash_for_entity entity_descriptor, entity
      core_module = core_module_for_entity(entity)
      base_hash = {'entity'=> write_core_entity_fields(core_module, entity)}
      
      children = hash_for_entity_children(entity_descriptor.children, entity)
      base_hash['entity']['children'] = children if children.length > 0

      base_hash
    end

    def write_entity_model_fields core_module, entity
      model_fields = {}
      core_module.model_fields {|mf| !mf.history_ignore? }.values.each do |mf|
        v = field_value(entity, mf)
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