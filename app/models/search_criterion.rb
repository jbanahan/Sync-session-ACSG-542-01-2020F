class SearchCriterion < ActiveRecord::Base
  include HoldsCustomDefinition
  include JoinSupport
  
  belongs_to :milestone_plan
  belongs_to :status_rule  
  belongs_to :search_setup
  
  validates  :model_field_uid, :presence => true
  validates  :operator, :presence => true
  
  def apply(p, module_chain = nil)
    p = p.where("1=1") if p.class.to_s == "Class"
    if module_chain.nil?
      set_module_chain p
    else
      @module_chain = module_chain
    end
    add_where(add_join(p))
  end
    
  
  def self.make_field_name(custom_definition)
    "*cf_#{custom_definition.id}"
  end

  #does the given value pass the criterion test
  def passes?(value_to_test)
    mf = find_model_field
    d = mf.data_type
    
    operators = {:eq => "eq", :co => "co", :sw => "sw", :ew => "ew", :null => "null", 
      :notnull => "notnull", :gt => "gt", :lt => "lt"}
    
    return value_to_test.nil? if self.operator == operators[:null]
    return !value_to_test.nil? if self.operator == operators[:notnull]
    
    if [:string, :text].include? d
      if self.operator == operators[:eq]
        return value_to_test.downcase == self.value.downcase
      elsif self.operator == operators[:co]
        return value_to_test.downcase.include?(self.value.downcase)
      elsif self.operator == operators[:sw]
        return value_to_test.downcase.start_with?(self.value.downcase)
      elsif self.operator == operators[:ew]
        return value_to_test.downcase.end_with?(self.value.downcase)
      end
    elsif d == :date
      self_val = Date.parse self.value.to_s
      if self.operator == operators[:eq]
        return value_to_test == self_val
      elsif self.operator == operators[:gt]
        return value_to_test > self_val
      elsif self.operator == operators[:lt]
        return value_to_test < self_val
      end
    elsif d == :boolean
      if self.operator == operators[:eq]
        self_val = ["t","true","yes","y"].include?(self.value.downcase)
        return value_to_test == self_val
      end  
    elsif [:decimal, :integer].include? d
      if self.operator == operators[:eq]
        return value_to_test == self.value
      elsif self.operator == operators[:gt]
        return value_to_test > self.value
      elsif self.operator == operators[:lt]
        return value_to_test < self.value
      elsif self.operator == operators[:sw]
        return value_to_test.to_s.start_with?(self.value.to_s)
      elsif self.operator == operators[:ew]
        return value_to_test.to_s.end_with?(self.value.to_s)
      end
    end
  end

  private
  
  def add_where(p)
    p.where(where_clause,where_value)
  end

  def where_clause
    mf = find_model_field
    table_name = mf.join_alias
    if custom_field? 
      c_def_id = mf.custom_id
      cd = CustomDefinition.find(c_def_id)
      if boolean_field?
        bool_val = where_value ? "custom_values.boolean_value = ?" : "(custom_values.boolean_value is null OR custom_values.boolean_value = ?)"
        "#{table_name}.id IN (SELECT custom_values.customizable_id FROM custom_values WHERE custom_values.custom_definition_id = #{c_def_id} AND #{bool_val})"
      else
        "#{table_name}.id IN (SELECT custom_values.customizable_id FROM custom_values WHERE custom_values.custom_definition_id = #{c_def_id} AND custom_values.#{cd.data_column} #{CriterionOperator.find_by_key(self.operator).query_string})"
      end
    else
      if boolean_field?
        bool_val = where_value ? 
          "#{mf.qualified_field_name} = ?" :
          "(#{mf.qualified_field_name} = ? OR #{mf.qualified_field_name} is null)"
      else
        "#{mf.qualified_field_name} #{CriterionOperator.find_by_key(self.operator).query_string}"
      end
    end
  end
  
  def boolean_field?
    return find_model_field.data_type==:boolean
  end
  
  def integer_field?
    return find_model_field.data_type==:integer
  end
  
  def decimal_field?
    return find_model_field.data_type==:decimal
  end

  #value formatted properly for the appropriate condition in the SQL
  def where_value
    return ["t","true","yes","y"].include? self.value.downcase if boolean_field?
    
    return self.value.to_i if integer_field?
    
    if self.operator=="co"
      return "%#{self.value}%"
    elsif self.operator=="sw"
      return "#{self.value}%"
    elsif self.operator=="ew"
      return "%#{self.value}"
    else
      return self.value
    end
  end

end
