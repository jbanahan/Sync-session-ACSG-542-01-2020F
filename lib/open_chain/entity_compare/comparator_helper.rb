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

    if entity_chain.length == 1
      return children
    else
      entity_children = []
      children.each do |child|
        entity_children.push *json_child_entities(child, *entity_chain[1..-1])
      end
      return entity_children.flatten
    end
  end

  # Simple helper to reach into the entity hash and extract model fields
  def mf(entity_hash, field_name)
    entity_hash = unwrap_entity(entity_hash)

    fields = entity_hash.try(:[], 'model_fields')
    value = nil
    if fields
      value = fields.try(:[], field_name)
    end
    value
  end

  def unwrap_entity(entity)
    # Just assume if the hash we're given doesn't have an entity key, that we've already
    # got the entity
    inner = entity.try(:[], 'entity')
    inner.presence || entity
  end

  def find_entity_object(entity)
    entity = unwrap_entity(entity)
    cm = CoreModule.find_by_class_name(entity['core_module'])
    obj = nil
    if cm
      obj = cm.klass.where(id: entity['record_id']).first
    end

    obj
  end


end; end; end