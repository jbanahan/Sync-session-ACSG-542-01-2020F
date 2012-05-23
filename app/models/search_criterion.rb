class SearchCriterion < ActiveRecord::Base
  include HoldsCustomDefinition
  include JoinSupport
  
  belongs_to :milestone_plan
  belongs_to :status_rule  
  belongs_to :search_setup
  belongs_to :instant_classification
  
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

  #does the given object pass the criterion test (assumes that the object will be of the type that the model field's process_query_parameter expects)
  def test? obj, user=nil
    mf = ModelField.find_by_uid(self.model_field_uid)
    passes?(mf.process_query_parameter(obj))
  end
  #does the given value pass the criterion test
  def passes?(value_to_test)
    mf = find_model_field
    d = mf.data_type

    nil_fails_operators = ["co","nc","sw","ew","gt","lt","bda","ada","adf","bdf"] #all of these operators should return false if value_to_test is nil
    return false if value_to_test.nil? && nil_fails_operators.include?(self.operator)

    return value_to_test.blank? if self.operator == "null" 
    return !value_to_test.blank? if self.operator == "notnull"
    
    if [:string, :text].include? d
      return self.value.nil? if value_to_test.nil? && self.operator != 'nq'
      if self.operator == "eq"
        return value_to_test.nil? ? self.value.nil? : value_to_test.downcase == self.value.downcase
      elsif self.operator == "co"
        return value_to_test.downcase.include?(self.value.downcase)
      elsif self.operator == "nc"
        return !value_to_test.downcase.include?(self.value.downcase)
      elsif self.operator == "sw"
        return value_to_test.downcase.start_with?(self.value.downcase)
      elsif self.operator == "ew"
        return value_to_test.downcase.end_with?(self.value.downcase)
      elsif self.operator == "nq"
        return value_to_test.nil? || value_to_test.downcase!=self.value.downcase
      elsif self.operator == "in"
        return break_rows(self.value.downcase).include?(value_to_test.downcase)
      end
    elsif [:date, :datetime].include? d
      vt = d==:date && !value_to_test.nil? ? value_to_test.to_date : value_to_test
      self_val = ["eq","gt","lt","nq"].include?(self.operator) ? Date.parse(self.value.to_s) : number_value(:integer,self.value)
      if self.operator == "eq"
        return vt == self_val
      elsif self.operator == "gt"
        return vt > self_val
      elsif self.operator == "lt"
        return vt < self_val
      elsif self.operator == "bda"
        return vt < self_val.days.ago.to_date #.to_date gets rid of times that screw up comparisons
      elsif self.operator == "ada"
        return vt >= self_val.days.ago.to_date
      elsif self.operator == "adf"
        return vt >= self_val.days.from_now.to_date
      elsif self.operator == "bdf"
        return vt < self_val.days.from_now.to_date
      elsif self.operator == "nq"
        return vt.nil?  || vt!=self_val
      end
    elsif d == :boolean
      self_val = ["t","true","yes","y"].include?(self.value.downcase)
      if self.operator == "eq"
        return value_to_test == self_val
      elsif self.operator == "nq"
        #testing not equal to true
        if ["t","true","yes","y"].include(self.value.downcase)
          return value_to_test.nil? || !value_to_test
        else
          return value_to_test
        end
      end  
    elsif [:decimal, :integer, :fixnum].include? d
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
      elsif self.operator == "nq"
        return value_to_test.nil? || value_to_test!=self_val
      elsif self.operator == "in"
        return break_rows(self.value.downcase).include?(value_to_test.to_s)
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
      cd = CustomDefinition.cached_find(c_def_id)
      if boolean_field?
        bool_val = where_value ? "custom_values.boolean_value = ?" : "(custom_values.boolean_value is null OR custom_values.boolean_value = ?)"
        "#{table_name}.id IN (SELECT custom_values.customizable_id FROM custom_values WHERE custom_values.custom_definition_id = #{c_def_id} AND #{bool_val})"
      elsif self.operator=='null'
        "((SELECT count(*) FROM custom_values where custom_values.custom_definition_id = #{c_def_id} AND custom_values.customizable_id = #{table_name}.id)=0) OR #{table_name}.id IN (SELECT custom_values.customizable_id FROM custom_values WHERE custom_values.custom_definition_id = #{c_def_id} AND #{CriterionOperator.find_by_key(self.operator).query_string("custom_values.#{cd.data_column}")})"
      else
        "#{table_name}.id IN (SELECT custom_values.customizable_id FROM custom_values WHERE custom_values.custom_definition_id = #{c_def_id} AND #{CriterionOperator.find_by_key(self.operator).query_string("custom_values.#{cd.data_column}")})"
      end
    else
      if boolean_field?
        bool_val = where_value ? 
          "#{mf.qualified_field_name} = ?" :
          "(#{mf.qualified_field_name} = ? OR #{mf.qualified_field_name} is null)"
      else
        CriterionOperator.find_by_key(self.operator).query_string(mf.qualified_field_name)
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

  def date_field?
    return find_model_field.data_type==:date
  end

  #value formatted properly for the appropriate condition in the SQL
  def where_value
    self_val = date_field? && !self.value.nil? && self.value.is_a?(Time)? self.value.to_date : self.value
    if boolean_field? && ['null','notnull'].include?(self.operator)
      return self.operator=='notnull'
    elsif boolean_field?
      return ["t","true","yes","y"].include? self_val.downcase if boolean_field?
    end
    
    return self_val.to_i if integer_field? && self.operator!="in"
    
    case self.operator
    when "co"
      return "%#{self_val}%"
    when "nc"
      return "%#{self_val}%"
    when "sw"
      return "#{self_val}%"
    when "ew"
      return "%#{self_val}"
    when "in"
      return break_rows(self_val)
    else
      return self_val
    end
  end

  def break_rows val
    val.strip.split(/[\r\n,\r,\n]/)
  end

end
