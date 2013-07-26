module CustomFieldSupport
  attr_accessor :lock_custom_values #if set to true, the object will no longer look to the database to retrieve any custom values and will just build new ones if they're not already injected / cached
  def self.included(base)
    base.instance_eval("has_many :custom_values, :as => :customizable, :dependent => :destroy")
  end
  
  def custom_definitions
    CustomDefinition.cached_find_by_module_type self.class
  end
  
  def get_custom_value custom_definition
    id = custom_definition.id
    cv = get_custom_value_by_overrides custom_definition
    return cv if cv
    cv = self.custom_values.find {|v| v.custom_definition_id == custom_definition.id} if cv.nil? && !self.lock_custom_values
    if cv.nil?
      cv = self.custom_values.build(:custom_definition => custom_definition)
      cv.value = custom_definition.default_value unless custom_definition.default_value.nil?
      @custom_value_cache[custom_definition.id] = cv unless @custom_value_cache.nil?
    end
    cv
  end

  def get_custom_value_by_label label
    get_custom_value CustomDefinition.find_by_label(label)
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
    get_custom_value CustomDefinition.find id
  end

  #when you inject a custom value, it will be the value returned by this instance's get_custom_value methods for the appropriate custom_definition for the life of the object, 
  #regardless of database changes. Basically, you're overriding any database or cache checks with a hard coded value for the lifetime of this object in memory.
  #use cautiously
  def inject_custom_value custom_value
    @injected = {} if @injected.nil?
    @injected[custom_value.custom_definition_id] = custom_value
  end

  private
  def get_custom_value_by_overrides(custom_definition)
    #if we've injected a value, that always wins
    return @injected[custom_definition.id] if @injected && @injected[custom_definition.id]
    #if there's a cache and the value is in it, return it
    return @custom_value_cache[custom_definition.id] unless @custom_value_cache.nil? || @custom_value_cache[custom_definition.id].nil?
    #if there's a cache then we've already loaded everything, so just build a new one
    return self.custom_values.build(:custom_definition=>custom_definition) unless @custom_value_cache.blank?
    #if we got here, there were no overrides
    return nil
  end
end
