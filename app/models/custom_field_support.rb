module CustomFieldSupport
  def self.included(base)
    base.instance_eval("has_many :custom_values, :as => :customizable, :dependent => :destroy")
  end
  
  def custom_definitions
    CustomDefinition.where(:module_type => self.class)
  end
  
  def get_custom_value(custom_definition)
    cv = self.custom_values.where(:custom_definition_id => custom_definition).first
    cv.nil? ? self.custom_values.build(:custom_definition => custom_definition) : cv
  end
end