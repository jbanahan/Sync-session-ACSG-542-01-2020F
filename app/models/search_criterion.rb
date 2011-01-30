class SearchCriterion < ActiveRecord::Base
  include HoldsCustomDefinition
  
  belongs_to :milestone_plan
  belongs_to :status_rule  
  belongs_to :search_setup
  
  validates  :model_field_uid, :presence => true
  validates  :condition, :presence => true
  validates  :value, :presence => true
  
  def apply(p)
    add_where(add_join(p))
  end
    
  
  def self.make_field_name(custom_definition)
    "*cf_#{custom_definition.id}"
  end

  def model_field
    ModelField.find_by_uid(self.model_field_uid)
  end
  
  private  
  def add_join(p)
    p = p.where("1=1") if p.class.to_s == "Class"
    mf_cm = model_field.core_module
    unless(mf_cm.class_name==p.klass.to_s)
      child_join = CoreModule.find_by_class_name(p.klass.to_s).child_joins[mf_cm]
      p = p.joins(child_join) unless child_join.nil?
    end
    p = p.joins(model_field.join_statement) unless model_field.join_statement.nil?
    p
  end
  
  def add_where(p)
    p.where(where_clause,where_value)
  end
  
  

  def where_clause
    table_name = model_field.join_alias
    if model_field.field_name.to_s.starts_with? "*cf_"
      c_def_id = model_field.field_name.to_s[4,model_field.field_name.to_s.length-1]
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
          "#{table_name}.#{model_field.field_name} = ?" :
          "(#{table_name}.#{model_field.field_name} = ? OR #{table_name}.#{model_field.field_name} is null)"
      else
        "#{table_name}.#{model_field.field_name} #{CriterionOperator.find_by_key(self.condition).query_string}"
      end
    end
  end
  
  def boolean_field?
    return model_field.data_type==:boolean
  end
  
  def integer_field?
    return model_field.data_type==:integer
  end
  
  def decimal_field?
    return model_field.data_type==:decimal
  end
  
  #value formatted properly for the appropriate condition in the SQL
  def where_value
    return ["t","true","yes","y"].include? self.value.downcase if boolean_field?
    
    return self.value.to_i if integer_field?
    
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
