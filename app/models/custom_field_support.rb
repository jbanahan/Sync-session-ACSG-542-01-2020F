module CustomFieldSupport
  def self.included(base)
    base.instance_eval("has_many :custom_values, :as => :customizable, :dependent => :destroy")
  end
  
  def custom_definitions
    CustomDefinition.cached_find_by_module_type self.class
  end
  
  def get_custom_value(custom_definition)
    return @injected[custom_definition.id] if @injected && @injected[custom_definition.id]
    return @custom_value_cache[custom_definition.id] unless @custom_value_cache.nil? || @custom_value_cache[custom_definition.id].nil?
    cv = self.connection.outside_transaction? ? CustomValue.cached_find_unique(custom_definition.id, self) : nil 
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
  def load_custom_values
    @custom_value_cache = {}
    CustomValue.where(:customizable_id=>self.id,:customizable_type=>self.class.to_s).each do |cv|
      @custom_value_cache[cv.custom_definition_id] = cv
    end
    true
  end

  def get_custom_value_by_id(id)
    get_custom_value(CustomDefinition.cached_find(id))
  end

  #when you inject a custom value, it will be the value returned by this instance's get_custom_value methods for the appropriate custom_definition for the life of the object, 
  #regardless of database changes. Basically, you're overriding any database or cache checks with a hard coded value for the lifetime of this object in memory.
  #use cautiously
  def inject_custom_value custom_value
    @injected = {} unless @injected
    @injected[custom_value.custom_definition_id] = custom_value
  end

end
