class SearchCriterion < ActiveRecord::Base
  belongs_to :milestone_plan
  belongs_to :status_rule  
  
  validates  :module_type, :presence => true
  validates  :field_name, :presence => true
  validates  :condition, :presence => true
  validates  :value, :presence => true
  
  def add_where(p)
    wc = where_clause
    wv = where_value
    p.where(wc,wv)
  end
  
  def self.make_field_name(custom_definition)
    "*cf_#{custom_definition.id}"
  end
  
  private  

  def where_clause
    table_name = CoreModule.find_by_class_name(self.module_type).table_name
    if self.field_name.starts_with? "*cf_"
      c_def_id = self.field_name[4,self.field_name.length-1]
      if c_def_id.to_i.to_s == c_def_id
        cd = CustomDefinition.find(c_def_id)
        if boolean_field?
          bool_val = where_value ? "custom_values.boolean_value = ?" : "(custom_values.boolean_value is null OR custom_values.boolean_value = ?)"
          "#{table_name}.id IN (SELECT custom_values.customizable_id FROM custom_values WHERE custom_values.custom_definition_id = #{c_def_id} AND #{bool_val})"
        else
          "#{table_name}.id IN (SELECT custom_values.customizable_id FROM custom_values WHERE custom_values.custom_definition_id = #{c_def_id} AND custom_values.#{cd.data_column} #{CriterionOperator.find_by_key(self.condition).query_string})"
        end
      else
        "1=0"
      end
    else
      if boolean_field?
        bool_val = where_value ? 
          "#{table_name}.#{self.field_name} = ?" :
          "(#{table_name}.#{self.field_name} = ? OR #{table_name}.#{self.field_name} is null)"
      else
        "#{table_name}.#{self.field_name} #{CriterionOperator.find_by_key(self.condition).query_string}"
      end
    end
  end
  
  def boolean_field?
    return ModelField.find_by_module_type_and_field_name(self.module_type.to_sym, self.field_name.to_sym).data_type==:boolean
  end
  
  #value formatted properly for the appropriate condition in the SQL
  def where_value
    return ["t","true","yes","y"].include? self.value.downcase if boolean_field?
    
    if self.condition=="co"
      return "%#{self.value}%"
    elsif self.condition=="sw"
      return "#{self.value}%"
    elsif self.condition=="ew"
      return "%#{self.value}"
    else
      return self.value
    end
  end

  
end
