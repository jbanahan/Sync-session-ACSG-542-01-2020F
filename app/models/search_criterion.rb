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

  def self.date_time_operators_requiring_timezone
    ['lt', 'gt', 'eq', 'nq']
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

    nil_fails_operators = ["co","nc","sw","ew","gt","lt","bda","ada","adf","bdf","pm"] #all of these operators should return false if value_to_test is nil
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
      # For date comparisons we want to make sure we're actually dealing w/ a Date
      # from the model object and not a date and time (essentially, we're just trimming 
      # the time portion if it's present).  Since the value is expected to be coming from
      # an actual ActiveRecord model, then the value_to_test should have already been 
      # converted to user local timezone, hence no need to adjust further
      vt = d==:date && !value_to_test.nil? ? value_to_test.to_date : value_to_test

      self_val = nil
      if d == :date && ["eq","gt","lt","nq"].include?(self.operator)
        self_val = Date.parse(self.value.to_s)
      elsif d == :datetime && !self.value.nil? && SearchCriterion.date_time_operators_requiring_timezone.include?(self.operator)
        # parse_date_time converts the datetime criterion into a UTC String (for the initial DB Query), what we're doing 
        # here is parsing that UTC string back into the user local time zone.
        # Adding the "UTC" informs the parse method that the given time string is in a different timezone
        self_val = Time.zone.parse((parse_date_time self.value) + " UTC")
      else
        self_val = number_value(:integer,self.value)
      end

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
      elsif self.operator == "pm"
        base_date = self_val.months.ago
        base_date = Date.new(base_date.year,base_date.month,1)
        return (vt < Time.now.to_date) && (vt >= base_date) && !(vt.month == 0.seconds.ago.month && vt.year == 0.seconds.ago.year)
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

  def date_time_field?
    return find_model_field.data_type == :datetime
  end

  #value formatted properly for the appropriate condition in the SQL
  def where_value
    if (!self.value.nil? && date_time_field? && SearchCriterion.date_time_operators_requiring_timezone.include?(self.operator))
      return parse_date_time self.value
    end

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

  def parse_date_time value
    # We need to adjut the user's date value for datetime fields to UTC and we're expecting the actual timezone
    # name to be in the criterion's value. For cases where it's not (ie. any datetime prior to this
    # changeset going live), we'll assume a timezone of "Eastern Time (US & Canada)".
    parsed_value = nil

    if value.is_a?(Time)
      parsed_value = value.getutc
    else 
      # Expect the string to be like YYYY-MM-DD HH:MM:SS Timezone.  With HH:MM:SS being optional.
      # Extract the timezone component from the string first, then we should be able to just
      # parse the rest of the string directly.
      
      # The regular expression here splits the date string up into 4 parts with only the first (the actual date)
      # being required.  The second group is just a throwaway (allowing for everything after the date to be
      # optional).  The third is the time segement (again - optional) and the forth is the timezone.
      # date - Allows numeric values and slashes or hyphens as seperators
      # time - A space must follow the date for time to get picked up, allows numbers or colon
      # time_zone - Anything that optionally follows the date and/or time is considered the time_zone
      if value.match /\A([\d\-\/]+)( +([\d:]+)? *(.*)?)?\z/
          date, time, time_zone = [$1, $3.nil? ? "00:00:00" : $3, Time.find_zone($4)]
          
          if time_zone.nil?
            # The following should never fail - it's our fallback
            time_zone = Time.find_zone! "Eastern Time (US & Canada)"
          end
          
          Time.use_zone(time_zone) do
            parsed_value = Time.zone.parse(date + " " + time)
            parsed_value = parsed_value.utc.to_formatted_s(:db) unless parsed_value.nil?
          end
      end 
    end
    parsed_value
  end

  def break_rows val
    # We don't have to worry any longer about carriage returns being sent (\r) by themselves to denote new lines.
    # No current operatring systems use this style to denote newlines any longer (Mac OS X is a unix and uses \n).
    val.strip.split(/\r?\n/)
  end

end
