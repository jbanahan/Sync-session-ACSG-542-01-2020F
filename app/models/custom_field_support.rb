module CustomFieldSupport
  def self.included(base)
    base.instance_eval("has_many :custom_values, :as => :customizable, :dependent => :destroy")
  end
  
  def custom_definitions
    CustomDefinition.where(:module_type => self.class)
  end
  
  def get_custom_value(custom_definition)
    cv = CustomValue.cached_find_unique custom_definition.id, self
    cv = self.custom_values.where(:custom_definition_id => custom_definition).first if cv.nil?
    cv.nil? ? self.custom_values.build(:custom_definition => custom_definition) : cv
  end

  def get_custom_value_by_id(id)
    get_custom_value(CustomDefinition.cached_find(id))
  end

end
