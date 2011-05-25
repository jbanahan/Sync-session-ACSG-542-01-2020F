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
    
    return value_to_test.nil? if self.operator == "null" 
    return !value_to_test.nil? if self.operator == "notnull"
    
    if [:string, :text].include? d
      if self.operator == "eq"
        return value_to_test.downcase == self.value.downcase
      elsif self.operator == "co"
        return value_to_test.downcase.include?(self.value.downcase)
      elsif self.operator == "sw"
        return value_to_test.downcase.start_with?(self.value.downcase)
      elsif self.operator == "ew"
        return value_to_test.downcase.end_with?(self.value.downcase)
      end
    elsif [:date, :datetime].include? d
      self_val = ["eq","gt","lt"].include?(self.operator) ? Date.parse(self.value.to_s) : number_value(:integer,self.value)
      if self.operator == "eq"
        return value_to_test == self_val
      elsif self.operator == "gt"
        return value_to_test > self_val
      elsif self.operator == "lt"
        return value_to_test < self_val
      elsif self.operator == "bda"
        return value_to_test.to_date < self_val.days.ago.to_date #.to_date gets rid of times that screw up comparisons
      elsif self.operator == "ada"
        return value_to_test.to_date >= self_val.days.ago.to_date
      elsif self.operator == "adf"
        return value_to_test.to_date >= self_val.days.from_now.to_date
      elsif self.operator == "bdf"
        return value_to_test.to_date < self_val.days.from_now.to_date
      end
    elsif d == :boolean
      if self.operator == "eq"
        self_val = ["t","true","yes","y"].include?(self.value.downcase)
        return value_to_test == self_val
      end  
    elsif [:decimal, :integer].include? d
      self_val = number_value d, self.value
      if self.operator == "eq"
        return value_to_test == self_val
      elsif self.operator == "gt"
        return value_to_test > self_val
      elsif self.operator == "lt"
        return value_to_test < self_val
      elsif self.operator == "sw"
        return value_to_test.to_s.start_with?(self.value.to_s)
      elsif self.operator == "ew"
        return value_to_test.to_s.end_with?(self.value.to_s)
      end
    end
  end

  private

  def number_value data_type, value
    sval = (value.blank? || !is_a_number(value) ) ? "0" : value
    data_type==:integer ? sval.to_i : sval.to_f
  end

  def is_a_number val
    begin Float(val) ; true end rescue false
  end
  
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
