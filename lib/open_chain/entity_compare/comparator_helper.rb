module OpenChain; module EntityCompare; module ComparatorHelper

  def get_json_hash bucket, key, version
    # If anything is blank here, return a blank hash.  This occurs most often in the comparators
    # when you're doing a comparison for an object that is brand new and thus has no previous
    # versions.
    json = {}
    if !bucket.blank? && !key.blank? && !version.blank?
      data = OpenChain::S3.get_versioned_data(bucket, key, version)
      json = ActiveSupport::JSON.decode(data) unless data.blank?
    end

    json
  end

  def parse_time time, input_timezone: 'UTC', output_timezone: "America/New_York"
    if !time.blank?
      ActiveSupport::TimeZone[input_timezone].parse(time).in_time_zone(output_timezone)
    else
      nil
    end
  end


  # This is a simple way to walk down a snapshot heirarchy and grab all the
  # children / grandchildren that you want to work with.
  #
  # For instance, if you want to work with all the commercial invoice lines
  # from a snapshot of an Entry: json_child_entities entry_json, "CommercialInvoice", "CommercialInvoiceLine"
  #
  # Note, you WILL ONLY receive the entities of the lowest level specified
  #
  # This is basically akin to doing an xpath expression like /root/child/grandchild
  def json_child_entities json, *entity_chain
    return [] if json.nil?

    # Handle receiving either the entity wrapper or the actual inner entity object.
    # .ie {"entity" => {"core_module" => "Module" .... } } or just {"core_module" => "Module" ... }
    root_entity = unwrap_entity(json)
    child_entities = root_entity.try(:[], 'children')

    children = []

    Array.wrap(child_entities).each do |child|
      children << child['entity'] if child['entity']['core_module'] == entity_chain.first
    end

    found = []
    if entity_chain.length == 1
      found = children
    else
      entity_children = []
      children.each do |child|
        entity_children.push(*json_child_entities(child, *entity_chain[1..-1]))
      end
      found = entity_children.flatten
    end

    if block_given?
      found.each {|f| yield f }
    end

    found
  end

  # Simple helper to reach into the entity hash and extract model fields
  # If you are working w/ a CustomField, you may include the CustomDefinition for the field
  # as the field_name
  def mf(entity_hash, field_name, coerce: true, split_values: false)
    if field_name.respond_to?(:model_field_uid)
      field_name = field_name.model_field_uid
    else
      field_name = field_name.to_s
    end

    entity_hash = unwrap_entity(entity_hash)

    fields = entity_hash.try(:[], 'model_fields')
    value = nil
    if fields
      value = fields.try(:[], field_name)
    end

    if value && coerce
      value = coerce_model_field_value(field_name, value)
    end

    # Entry is just used here as a concrete implemetation of the CoreObjectModule's split_newline_values method
    split_values ? Entry.split_newline_values(value) : value
  end

  def unwrap_entity(entity)
    # Just assume if the hash we're given doesn't have an entity key, that we've already
    # got the entity
    inner = entity.try(:[], 'entity')
    inner.presence || entity
  end

  def find_entity_object(entity)
    entity = unwrap_entity(entity)
    cm = find_core_module(entity)
    obj = nil
    if cm
      obj = cm.klass.where(id: entity['record_id']).first
    end

    obj
  end

  def find_entity_object_by_snapshot_values(snapshot, fields_hash = {})
    entity = unwrap_entity(snapshot)
    cm = find_core_module(entity)
    obj = nil
    if cm && fields_hash.size > 0
      relation = cm.klass
      fields_hash.each_pair do |entity_attribute, mf_uid|
        relation = relation.where(entity_attribute => mf(entity, mf_uid))
      end

      obj = relation.first
    end

    obj
  end

  def find_core_module snapshot_entity
    cm = CoreModule.find_by_class_name(snapshot_entity['core_module'])
  end

  # This method assumes the values given are coming raw from a snapshot JSON,
  # and then converts that value back to the data type that is expected that the model
  # field represents.  This largely exists for decimal, date, datetime fields.
  def coerce_model_field_value model_field_uid, value
    return nil if value.nil?

    # Handled just in case we remove a model field...in this case we just want the raw value returned
    field = ModelField.find_by_uid model_field_uid
    return value if field.blank?

    case field.data_type.to_sym
    when :date
      return value.blank? ? nil : Date.strptime(value, "%Y-%m-%d")
    when :datetime
      # The date value should all be written out in UTC, so make sure they're read back as such, but then
      # make sure they're returned to the caller using the current Time.zone value
      return value.blank? ? nil : ActiveSupport::TimeZone["UTC"].parse(value).in_time_zone(Time.zone)
    when :decimal
      # Rails stores decimals as string (due to double rounding issues in javascript),
      # so handle the datatype conversion back to BigDecimal
      return value.blank? ? nil : BigDecimal(value.to_s)
    else
      # all other object types are handled natively by json, so we don't have
      # to do anything with them here (integer, string, boolean)
      return value
    end
  end

  # Returns an hash of any of the fields that changed between the two hashes. Key = Field name, Value = new field value
  # NOTE:  This method will not descend to child levels, so the fields given must represent
  # fields from the given object hash (.ie don't pass line level fields when the hash represents a header entity)
  def changed_fields old_hash, new_hash, fields
    changes = {}
    Array.wrap(fields).each do |field|
      new_value = mf(new_hash, field)
      if mf(old_hash, field) != new_value
        changes[field] = new_value
      end
    end

    changes
  end

  def any_changed_fields? old_hash, new_hash, fields
    changed_fields(old_hash, new_hash, fields).size > 0
  end

  def json_entity_type_and_id hash
    entity = unwrap_entity(hash)
    [entity["core_module"], entity["record_id"]]
  end

  def record_id hash
    unwrap_entity(hash)["record_id"]
  end

  # Returns true if any of the model fields given in model_field_uids are different between
  # the old and new snapshot entities given.
  def any_value_changed? old_json_entity, new_json_entity, model_field_uids
    Array.wrap(model_field_uids).each do |uid|
      old_value = mf(old_json_entity, uid)
      new_value = mf(new_json_entity, uid)

      return true if old_value != new_value
    end

    return false
  end

  # Shortcut for checking if any value given by the model_field_uids array changed in the snapshot's top level entity
  # (.ie entry, shipment, order, etc).
  def any_root_value_changed? old_bucket, old_key, old_version, new_bucket, new_key, new_version, model_field_uids
    old_json = get_json_hash(old_bucket, old_key, old_version)
    new_json = get_json_hash(new_bucket, new_key, new_version)

    return any_value_changed?(old_json, new_json, model_field_uids)
  end

  # This method simply loops though the supplied list of snapshot entity hashes
  # and finds one that has the same core_module and record_id values.
  def find_matching_entity_hash entity, list
    cm, id = json_entity_type_and_id(entity)
    list.find do |other_entity|
      other_cm, other_id = json_entity_type_and_id(other_entity)
      other_cm == cm && other_id == id
    end
  end

  # Returns true if any entity from the primary list is not in the secondary list.
  # NOTE: This method is ONLY unidirectional, it does not check if the primary list is missing
  # entities that might be in the secondary list
  def any_entities_missing_from_list? primary_list, secondary_list
    primary_list.each do |entity|
      return true if find_matching_entity_hash(entity, secondary_list).nil?
    end
    false
  end

  # This method returns true if any entity from either list is missing from the other.
  # This method can be used to tell if any child object was added or removed from a snapshot entity.
  def any_entities_missing_from_lists? primary_list, secondary_list
    # If any primary entities are missing from the secondary entities return true
    return true if any_entities_missing_from_list?(primary_list, secondary_list)
    # Now do the inverse and validate that the secondary list has the same entities
    any_entities_missing_from_list?(secondary_list, primary_list)
  end

  # Returns true if the outermost entity in the snapshot has any failed business rules.
  def failed_business_rules? snapshot
    entity = unwrap_entity(snapshot)
    cm = find_core_module(entity)
    prefix = CoreModule.module_abbreviation(cm)

    return !mf(snapshot, "#{prefix}_failed_business_rules").blank?
  end

  def added_child_entities old_snapshot, new_snapshot, *entity_chain
    old_child_entities = json_child_entities(old_snapshot, *entity_chain)
    new_child_entities = json_child_entities(new_snapshot, *entity_chain)

    new_entities = []
    # For each new child entity, see if the old snapshot has that object (we determine if it's different based on entity id,
    # which means in cases where an objects descendents are destroyed / replaced then methdo will not work, it will recognize
    # all the descendants in the new snapshot as new.)
    new_child_entities.each do |entity|
      id = record_id(entity)

      old_entity = old_child_entities.find {|e| id == record_id(e) }
      new_entities << entity if old_entity.nil?
    end

    new_entities
  end

end; end; end