module CustomFieldSupport
  def self.included(base)
    base.instance_eval("has_many :custom_values, :as => :customizable, :dependent => :destroy")
  end
  
  def custom_definitions
    CustomDefinition.cached_find_by_module_type self.class
  end
  
  def get_custom_value(custom_definition)
    cv = get_custom_value_by_overrides custom_definition.id
    return cv if cv
#    cv = self.connection.outside_transaction? ? CustomValue.cached_find_unique(custom_definition.id, self) : nil 
    cv = self.custom_values.where(:custom_definition_id => custom_definition).first if cv.nil?
    if cv.nil?
      cv = self.custom_values.build(:custom_definition => custom_definition)
      cv.value = custom_definition.default_value unless custom_definition.default_value.nil?
      @custom_value_cache[custom_definition.id] = cv unless @custom_value_cache.nil?
    end
    cv
  end

  #pre-loads all custom values for the object into memory.  
  #once this is called, the object will no longer hit the DB to get refreshed objects, so you shouldn't change the values through anything
  #except this object's returned CustomValue objects for the lifetime of this object
  def load_custom_values custom_value_collection = CustomValue.where(:customizable_id=>self.id,:customizable_type=>self.class.to_s)
    @custom_value_cache = {}
    custom_value_collection.each do |cv|
      @custom_value_cache[cv.custom_definition_id] = cv
    end
    true
  end

  # updates the custom value in the database (creating the record if needed)
  # custom_definition can be either a CustomDefinition object or an integer representing the CustomDefinition#id
  def update_custom_value! custom_definition, value
    cd = custom_definition
    cd = CustomDefinition.find_by_id custom_definition if custom_definition.is_a?(Numeric)
    cv = get_custom_value(cd)
    cv.value = value
    cv.save!
  end

  def get_custom_value_by_id(id)
    cv = get_custom_value_by_overrides id
    return cv if cv
    get_custom_value(CustomDefinition.cached_find(id))
  end

  #when you inject a custom value, it will be the value returned by this instance's get_custom_value methods for the appropriate custom_definition for the life of the object, 
  #regardless of database changes. Basically, you're overriding any database or cache checks with a hard coded value for the lifetime of this object in memory.
  #use cautiously
  def inject_custom_value custom_value
    @injected = {} unless @injected
    @injected[custom_value.custom_definition_id] = custom_value
  end

  private
  def get_custom_value_by_overrides(custom_definition_id)
    return @injected[custom_definition_id] if @injected && @injected[custom_definition_id]
    return @custom_value_cache[custom_definition_id] unless @custom_value_cache.nil? || @custom_value_cache[custom_definition_id].nil?
    return nil
  end
end
