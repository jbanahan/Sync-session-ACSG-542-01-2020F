module CustomFieldSupport
  def self.included(base)
    base.instance_eval("has_many :custom_values, :as => :customizable, :dependent => :destroy")
  end
  
  def custom_definitions
    CustomDefinition.where(:module_type => self.class)
  end
  
  def get_custom_value(custom_definition)
    return @injected[custom_definition.id] if @injected && @injected[custom_definition.id]
    cv = self.connection.outside_transaction? ? CustomValue.cached_find_unique(custom_definition.id, self) : nil 
    cv = self.custom_values.where(:custom_definition_id => custom_definition).first if cv.nil?
    cv.nil? ? self.custom_values.build(:custom_definition => custom_definition) : cv
  end

  def get_custom_value_by_id(id)
    get_custom_value(CustomDefinition.cached_find(id))
  end

  #when you inject a custom value, it will be the value returned by this instance's get_custom_value methods for the appropriate custom_definition for the life of the object, 
  #regardless of database changes. Basically, you're overriding any database or cache checks with a hard coded value.
  #use cautiously
  def inject_custom_value custom_value
    @injected = {} unless @injected
    @injected[custom_value.custom_definition_id] = custom_value
  end

end
