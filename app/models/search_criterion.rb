class SearchCriterion < ActiveRecord::Base
  include HoldsCustomDefinition
  
  belongs_to :milestone_plan
  belongs_to :status_rule  
  belongs_to :search_setup
  
  validates  :model_field_uid, :presence => true
  validates  :operator, :presence => true
  validates  :value, :presence => true
  
  def apply(p, module_chain = nil)
    p = p.where("1=1") if p.class.to_s == "Class"
    if module_chain.nil?
      if self.search_setup.nil?
        cm = CoreModule.find_by_class_name(p.klass.to_s)
        if cm.nil?
          @module_chain = nil
        else
          @module_chain = cm.default_module_chain
        end
      else
        @module_chain = self.search_setup.module_chain
      end
    else
      @module_chain = module_chain
    end
    add_where(add_join(p))
  end
    
  
  def self.make_field_name(custom_definition)
    "*cf_#{custom_definition.id}"
  end

  def model_field
    ModelField.find_by_uid(self.model_field_uid)
  end
  
  #does the given value pass the criterion test
  def passes?(value_to_test)
    mf = model_field
    d = mf.data_type
    
    operators = {:eq => "eq", :co => "co", :sw => "sw", :ew => "ew", :null => "null", 
      :notnull => "notnull", :gt => "gt", :lt => "lt"}
    
    return value_to_test.nil? if self.operator == operators[:null]
    return !value_to_test.nil? if self.operator == operators[:notnull]
    
    if [:string, :text].include? d
      if self.operator == operators[:eq]
        return self.value == value_to_test
      elsif self.operator == operators[:co]
        return self.value.include?(value_to_test)
      elsif self.operator == operators[:sw]
        return self.value.start_with?(value_to_test)
      elsif self.operator == operators[:ew]
        return self.value.end_with?(value_to_test)
      end
    elsif d == :date
      self.value = Date.parse self.value.to_s
      if self.operator == operators[:eq]
        return self.value == value_to_test
      elsif self.operator == operators[:gt]
        return self.value > value_to_test
      elsif self.operator == operators[:lt]
        return self.value < value_to_test
      end
    elsif d == :boolean
      if self.operator == operators[:eq]
        self_val = ["t","true","yes","y"].include?(self.value.downcase)
        return value_to_test == self_val
      end  
    elsif d == :decimal
      if self.operator == operators[:eq]
        return self.value == value_to_test
      elsif self.operator == operators[:gt]
        return self.value > value_to_test
      elsif self.operator == operators[:lt]
        return self.value < value_to_test
      elsif self.operator == operators[:sw]
        return self.value.to_s.start_with?(value_to_test.to_s)
      elsif self.operator == operators[:ew]
        return self.value.to_s.end_with?(value_to_test.to_s)
      end
    elsif d == :integer
      if self.operator == operators[:eq]
        return self.value == value_to_test
      elsif self.operator == operators[:gt]
        return self.value > value_to_test
      elsif self.operator == operators[:lt]
        return self.value < value_to_test
      elsif self.operator == operators[:sw]
        return self.value.to_s.start_with?(value_to_test.to_s)
      elsif self.operator == operators[:ew]
        return self.value.to_s.end_with?(value_to_test.to_s)
      end
    end
  end

  private  
  def add_join(p)
      
    mf_cm = model_field.core_module
    p = add_parent_joins p, @module_chain, mf_cm unless @module_chain.nil?
    p = p.joins(model_field.join_statement) unless model_field.join_statement.nil?
    p
  end

  def add_parent_joins(p,module_chain,target_module)
    add_parent_joins_recursive p, module_chain, target_module, module_chain.first
  end
  def add_parent_joins_recursive(p, module_chain, target_module, current_module) 
    new_p = p
    child_module = module_chain.child current_module
    unless child_module.nil?
      child_join = current_module.child_joins[child_module]
      new_p = p.joins(child_join) unless child_join.nil?
      unless child_module==target_module
        new_p = add_parent_joins_recursive new_p, module_chain, target_module, child_module
      end
    end
    new_p
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
          "#{table_name}.id IN (SELECT custom_values.customizable_id FROM custom_values WHERE custom_values.custom_definition_id = #{c_def_id} AND custom_values.#{cd.data_column} #{CriterionOperator.find_by_key(self.operator).query_string})"
        end
      else
        "1=0"
      end
    else
      if boolean_field?
        bool_val = where_value ? 
          "#{model_field.qualified_field_name} = ?" :
          "(#{model_field.qualified_field_name} = ? OR #{model_field.qualified_field_name} is null)"
      else
        "#{model_field.qualified_field_name} #{CriterionOperator.find_by_key(self.operator).query_string}"
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
