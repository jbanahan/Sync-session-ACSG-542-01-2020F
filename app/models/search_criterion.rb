# == Schema Information
#
# Table name: search_criterions
#
#  automated_billing_setup_id       :integer
#  business_validation_rule_id      :integer
#  business_validation_template_id  :integer
#  created_at                       :datetime         not null
#  custom_definition_id             :integer
#  custom_report_id                 :integer
#  custom_view_template_id          :integer
#  id                               :integer          not null, primary key
#  imported_file_id                 :integer
#  include_empty                    :boolean
#  instant_classification_id        :integer
#  milestone_notification_config_id :integer
#  model_field_uid                  :string(255)
#  operator                         :string(255)
#  search_run_id                    :integer
#  search_setup_id                  :integer
#  secondary_model_field_uid        :string(255)
#  state_toggle_button_id           :integer
#  status_rule_id                   :integer
#  updated_at                       :datetime         not null
#  value                            :text
#
# Indexes
#
#  business_validation_rule                                     (business_validation_rule_id)
#  business_validation_template                                 (business_validation_template_id)
#  index_search_criterions_on_automated_billing_setup_id        (automated_billing_setup_id)
#  index_search_criterions_on_custom_report_id                  (custom_report_id)
#  index_search_criterions_on_custom_view_template_id           (custom_view_template_id)
#  index_search_criterions_on_imported_file_id                  (imported_file_id)
#  index_search_criterions_on_milestone_notification_config_id  (milestone_notification_config_id)
#  index_search_criterions_on_search_run_id                     (search_run_id)
#  index_search_criterions_on_search_setup_id                   (search_setup_id)
#  index_search_criterions_on_state_toggle_button_id            (state_toggle_button_id)
#

class SearchCriterion < ActiveRecord::Base
  include HoldsCustomDefinition
  include JoinSupport

  belongs_to :milestone_plan
  belongs_to :status_rule
  belongs_to :search_setup
  belongs_to :instant_classification
  belongs_to :business_validation_rule
  belongs_to :business_validation_template
  belongs_to :state_toggle_button, inverse_of: :search_criterions
  belongs_to :custom_view_template, inverse_of: :search_criterions

  validates  :model_field_uid, :presence => true
  validates  :operator, :presence => true

  CRITERIONS = {
    'eq'=> 'Equals',
    'eqf'=> 'Equals (Field Including Time)',
    'eqfd'=> 'Equals (Field)',
    'nq'=> 'Not Equal To',
    'nqf'=> 'Not Equal To (Field Including Time)',
    'nqfd'=> 'Not Equal To (Field)',
    'gt'=> 'After',
    'gteq'=> 'After',
    'lt'=> 'Before',
    'sw'=> 'Starts With',
    'ew'=> 'Ends With',
    'nsw'=> 'Does Not Start With',
    'new'=> 'Does Not End With',
    'co'=> 'Contains',
    'nc'=> "Doesn't Contain",
    'in'=> 'One Of',
    'notin'=> 'Not One Of',
    'bda'=> 'Before _ Days Ago',
    'ada'=> 'After _ Days Ago',
    'bdf'=> 'Before _ Days From Now',
    'adf'=> 'After _ Days From Now',
    'bma'=> 'Before _ Months Ago',
    'ama'=> 'After _ Months Ago',
    'bmf'=> 'Before _ Months From Now',
    'amf'=> 'After _ Months From Now',
    'pm'=> 'Previous _ Months',
    'cmo'=> 'Current Month',
    'pqu'=> 'Previous _ Quarters',
    'cqu'=> 'Current Quarter',
    'pfcy'=> 'Previous _ Full Calendar Years',
    'cytd'=> 'Current Year To Date',
    'null'=> 'Is Empty',
    'notnull'=> 'Is Not Empty',
    'regexp'=> 'Regex',
    'notregexp'=> 'Not Regex',
    'afld'=> 'After (Field)',
    'bfld'=> 'Before (Field)',
    'dt_regexp'=> 'Regex',
    'dt_notregexp'=> 'Not Regex'
  }

  def operator_label
    CRITERIONS[self.operator]
  end

  def json current_user
    mf = self.model_field
    {:mfid=>self.model_field_uid,:label=>(mf.can_view?(current_user) ? mf.label : ModelField.disabled_label),:operator=>self.operator,:value=>self.value,:datatype=>self.model_field.data_type,:include_empty=>self.include_empty?}
  end

  def core_module
    self.model_field.core_module
  end

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
    ['lt', 'gt', 'gteq', 'eq', 'nq']
  end

  #does the given object pass the criterion test (assumes that the object will be of the type that the model field's process_query_parameter expects)
  def test? obj, user=nil, opts={}
    mf = ModelField.find_by_uid(self.model_field_uid)
    return false if mf.disabled?

    r = false
    if field_relative?
      # for relative fields, if a secondary object is needed to supply a value (ie. when we're dealing with
      # objects from mutiple heirarchical levels, we're expecting the obj passed in to be an array containing the appropriate
      # model objects to test values against..first index is primary object, second is secondary.
      # Otherwise, the same object will be used for both fields.
      mf_two = get_relative_model_field

      primary_obj, secondary_obj = [obj, obj]
      if obj.is_a? Enumerable
        primary_obj, secondary_obj = obj.take(2)
      end

      r = passes_relative? mf.process_query_parameter(primary_obj), get_relative_model_field.process_query_parameter(secondary_obj), opts
    elsif field_decimal?
      mf_two = get_secondary_model_field

      r = passes_decimal? mf, mf_two, obj
    else
      r = passes?(mf.process_query_parameter(obj), opts)
    end
    r
  end

  def add_where(p)
    value = where_value
    p.where(where_clause(value), value)
  end

  def where_clause sql_value
    mf = find_model_field
    # Disabled fields should cause all output to cease on a report.
    return "1 = 0" if mf.disabled?

    if field_relative?
      return relative_where_clause
    end

    if field_decimal?
      return decimal_where_clause
    end

    table_name = mf.join_alias
    clause = nil

    if custom_field? && !mf.user_field? && !mf.address_field?
      cd = mf.custom_definition
      custom_core = cd.model_field.core_module

      join_identifier = "#{table_name}." + ((mf.core_module == custom_core) ? "id" : "#{custom_core.klass.to_s.underscore}_id")

      base_select = "SELECT custom_values.customizable_id FROM custom_values WHERE custom_values.custom_definition_id = #{cd.id} AND custom_values.customizable_type = '#{cd.module_type}'"
      if boolean_field?
        clause = "custom_values.boolean_value = ?"
        if self.include_empty || !sql_value
          clause = "(#{clause} OR custom_values.boolean_value IS NULL)"
        end
        clause = "#{join_identifier} IN (#{base_select} AND #{clause})"
      elsif self.operator=='null'
        clause = "#{join_identifier} NOT IN (#{base_select} AND custom_values.customizable_id = #{table_name}.id AND length(custom_values.#{cd.data_column}) > 0)"
      elsif self.operator=='notnull'
        clause = "#{join_identifier} IN (#{base_select} AND custom_values.customizable_id = #{table_name}.id AND length(custom_values.#{cd.data_column}) > 0)"
      else
        clause = "#{join_identifier} IN (#{base_select} AND #{CriterionOperator.find_by_key(self.operator).query_string("custom_values.#{cd.data_column}", mf.data_type, self.include_empty)})"
      end

      # The core object may not actually have custom value rows yet for a particualr custom definition
      # if a new custom definition was added to the system.  To account for this we'll also find any
      # results that are missing fields if "Include Empty" is checked.
      if self.include_empty
        clause += " OR (#{join_identifier} NOT IN (#{base_select}))"
      end

      clause
    else
      if boolean_field?
        clause = "#{mf.qualified_field_name} = ?"
        if self.include_empty || !sql_value
          clause = "(#{clause} OR #{mf.qualified_field_name} IS NULL)"
        end
      else
        clause = CriterionOperator.find_by_key(self.operator).query_string(mf.qualified_field_name, mf.data_type, self.include_empty)
      end
    end

    if self.include_empty && mf.core_module
      # For "Include Empty" we also need to be able to catch cases where we're seaching over child tables
      # that may not have records for the field we're searching over.  .ie Product Search with a search criterion
      # of Classification ISO Code of Is Empty.  The result needs to include every product that doesn't have
      # classifications.

      # Technically, this is only really needed for child tables, but there's no harm in including the clause even for parent ones
      # since the real primary key (ie id) columns are being referenced
      clause += " OR #{mf.core_module.table_name}.#{mf.core_module.klass.primary_key} IS NULL"
    end

    clause
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

  def secondary_model_field
    mf_two = nil
      if field_relative?
        mf_two = get_relative_model_field
      end
    mf_two
  end

  #value formatted properly for the appropriate condition in the SQL
  def where_value
    val = self.model_field.preprocess_search_value(self.value)
    if (!val.nil? && date_time_field? && SearchCriterion.date_time_operators_requiring_timezone.include?(self.operator))
      return parse_date_time val
    end

    self_val = date_field? && !val.nil? && val.is_a?(Time)? val.to_date : val
    if boolean_field? && ['null','notnull'].include?(self.operator)
      return self.operator=='notnull'
    elsif boolean_field?
      return ["t","true","yes","y"].include? self_val.downcase
    end

    case self.operator
    when "co"
      return "%#{self_val}%"
    when "nc"
      return "%#{self_val}%"
    when "sw", "nsw"
      return "#{self_val}%"
    when "ew", "new"
      return "%#{self_val}"
    when "in", "notin"
      return break_rows(self_val)
    when "regexp"
      return "#{self_val}"
    else
      # We want the actual data types here, not string representations, primarily to avoid unecessary DB type-casting to strings in the query
      # self_val could be null here if the operator is one of the null value based ones
      if self_val
        self_val = self_val.to_i if integer_field?
        self_val = BigDecimal.new(self_val) if decimal_field?
      end

      return self_val
    end
  end

  # Quarters are defined simply: 1-4, representing Jan-Mar, Apr-Jun, Jul-Sep and Oct-Dec.
  # This method gets the number representing the current quarter.
  def self.get_quarter_number d
    ((d.month - 1) / 3) + 1
  end

  # Determines the starting date of a quarter.  Providing quarter 3 for 2017 would, for example, return July 1, 2017.
  def self.get_quarter_start_date quarter, year
    Date.new(year, ((quarter - 1) * 3) + 1, 1)
  end

  # Goes back in time by the specified number of quarters, returning the start date to that quarter.
  # For example, if this method was called against August 4, 2017 (quarter 3) with a quarter count of 4, it would
  # return July 1, 2016: the beginning of the summer quarter 4 quarters (a year) prior.  If a negative quarter_count
  # is provided, the method works in the opposite direction, looking into a later quarter.
  def self.get_previous_quarter_start_date d, quarter_count
    month_adjusted_d = d - (quarter_count * 3).months
    get_quarter_start_date(get_quarter_number(month_adjusted_d), month_adjusted_d.year)
  end

  # Looks forward from a date by the specified number of quarters, returning the start date to that quarter.
  # For example, if this method was called against August 4, 2017 (quarter 3) with a quarter count of 4, it would
  # return July 1, 2018: the beginning of the summer quarter 4 quarters (a year) later.
  def self.get_next_quarter_start_date d, quarter_count
    get_previous_quarter_start_date d, -quarter_count
  end

  private

  def field_decimal?
    ['nqfdec', 'eqfdec', 'gtfdec', 'ltfdec'].include? self.operator
  end

  def field_relative?
    ['bfld', 'afld', 'eqf', 'nqf', 'nqfd', 'eqfd'].include? self.operator
  end

  def get_secondary_model_field
    ModelField.find_by_uid self.secondary_model_field_uid
  end

  def get_relative_model_field
    ModelField.find_by_uid self.value
  end

  def passes_decimal? first_field, second_field, obj
    passes = false

    if first_field.blank? || second_field.blank?
      passes = self.include_empty?
    else
      # We want to run the math here since it is universal across all cases.
      field_one_value = first_field.process_query_parameter(obj)
      field_two_value = second_field.process_query_parameter(obj)

      decimal_value = (((field_one_value - field_two_value) / field_two_value).abs) * 100

      case self.operator
      when 'nqfdec'
        passes = decimal_value != BigDecimal.new(self.value)
      when 'eqfdec'
        passes = decimal_value == BigDecimal.new(self.value)
      when 'gtfdec'
        passes = decimal_value < BigDecimal.new(self.value)
      when 'ltfdec'
        passes = decimal_value > BigDecimal.new(self.value)
      end
    end

    passes
  end

  def passes_relative? my_value, other_value, opts
    my_values = opts[:split_field] ? split(my_value) : [my_value]
    results = []
    my_values.each do |my_value|
      passes = false

      if my_value.blank? || other_value.blank?
        passes = self.include_empty?
      else
        # We're specifically truncating the time values for these (even for on datetimes fields) to try and avoid
        # confusion.  If we need to have after/before field operators for more advanced usage we'll create a new
        # operator type that explicity states time is being compared.
        case self.operator
        when 'bfld'
          passes = my_value.to_date < other_value.to_date
        when 'afld'
          passes = my_value.to_date > other_value.to_date
        when 'eqf'
          passes = my_value == other_value
        when 'nqf'
          passes = my_value != other_value
        when 'eqfd'
          passes = my_value.to_date == other_value.to_date
        when 'nqfd'
          passes = my_value.to_date != other_value.to_date
        end
      end
      results << passes
    end
    opts[:pass_if_any] ? results.any? : results.all?
  end

  def decimal_where_clause
    first_mf = ModelField.find_by_uid(self.model_field_uid)
    second_mf = get_secondary_model_field

    clause = ""
    case self.operator
    when 'nqfdec'
      clause = "(ABS((#{first_mf.qualified_field_name}-#{second_mf.qualified_field_name})/#{second_mf.qualified_field_name}) * 100) != #{self.value}"
    when 'eqfdec'
      clause = "(ABS((#{first_mf.qualified_field_name}-#{second_mf.qualified_field_name})/#{second_mf.qualified_field_name}) * 100) = #{self.value}"
    when 'gtfdec'
      clause = "(ABS((#{first_mf.qualified_field_name}-#{second_mf.qualified_field_name})/#{second_mf.qualified_field_name}) * 100) < #{self.value}"
    when 'ltfdec'
      clause = "(ABS((#{first_mf.qualified_field_name}-#{second_mf.qualified_field_name})/#{second_mf.qualified_field_name}) * 100) > #{self.value}"
    end

    clause
  end
  def relative_where_clause
    my_mf = find_model_field
    other_mf = get_relative_model_field
    mysql_user_time_zone = Time.zone.tzinfo.name
    really_old_date = Time.new("1901", "01", "01", "00", "00", "00")

    if ['eqf', 'nqf', 'eqfd', 'nqfd'].include? self.operator
      main_field_query = if my_mf.data_type == :datetime
                          "convert_tz(#{my_mf.qualified_field_name}, 'GMT', '#{mysql_user_time_zone}')"
                         else
                           "#{my_mf.qualified_field_name}"
                         end
      other_field_query = if other_mf.data_type == :datetime
                            "convert_tz(#{other_mf.qualified_field_name}, 'GMT', '#{mysql_user_time_zone}')"
                          else
                            "#{other_mf.qualified_field_name}"
                          end
    end

    clause = ""
    case self.operator
    when 'bfld'
      clause = "#{my_mf.qualified_field_name} < #{other_mf.qualified_field_name}"
    when 'afld'
      clause = "#{my_mf.qualified_field_name} > #{other_mf.qualified_field_name}"
    when 'eqf'
      clause = "IFNULL(#{main_field_query},'#{really_old_date}') = IFNULL(#{other_field_query}, '#{really_old_date}')"
    when 'nqf'
      clause = "IFNULL(#{main_field_query},'#{really_old_date}') <> IFNULL(#{other_field_query}, '#{really_old_date}')"
    when 'eqfd'
      clause = "DATE(IFNULL(#{main_field_query},'#{really_old_date}')) = DATE(IFNULL(#{other_field_query}, '#{really_old_date}'))"
    when 'nqfd'
      clause = "DATE(IFNULL(#{main_field_query},'#{really_old_date}')) <> DATE(IFNULL(#{other_field_query}, '#{really_old_date}'))"
    end

    clause
  end

  def split str
    str.blank? ? [str] : str.split("\n ")
  end

  #does the given value pass the criterion test
  def passes? value_to_test, opts
    mf = find_model_field
    return false if mf.disabled?
    values_to_test = opts[:split_field] ? split(value_to_test) : [value_to_test]
    results = []
    values_to_test.each { |value| results << mf_passes?(mf, value) }
    opts[:pass_if_any] ? results.any? : results.all?
  end

  def mf_passes?(mf, value_to_test)

    d = mf.data_type

    # If we include empty values, Returns true for nil, blank strings (ie. only whitespace), or anything that equals zero
    return true if (self.include_empty && ((value_to_test.blank? && value_to_test != false) || value_to_test == 0))
    #all of these operators should return false if value_to_test is nil
    
    # Generally speaking, any operator that is meant to compare a database DATE value to something else, where the
    # database date value could be nil, should be included in this array and return false.
    return false if value_to_test.nil? && ["co","nc","sw","ew","gt","gteq","lt","bda","ada","adf","bdf","pm","bma","ama","amf","bmf","cmo","pqu","cqu","pfcy","cytd"].include?(self.operator)

    # Does the given value pass the criterion test (this is primarily for boolean fields)
    # Since we're considering blank strings as empty, we should also consider 0 (ie. blank number) as empty as well
    return (value_to_test.blank? || value_to_test == 0) if self.operator == "null"
    return !value_to_test.blank? if self.operator == "notnull"

    if [:string, :text].include? d
      return self.value.nil? if value_to_test.nil? && self.operator != 'nq'
      if self.operator == "eq"
        # The rstrip here is to match how the equality operator works in MySQL.
        return value_to_test.nil? ? self.value.nil? : value_to_test.downcase.rstrip == self.value.downcase.rstrip
      elsif self.operator == "co"
        return value_to_test.downcase.include?(self.value.downcase)
      elsif self.operator == "nc"
        return !value_to_test.downcase.include?(self.value.downcase)
      elsif self.operator == "sw"
        return value_to_test.downcase.start_with?(self.value.downcase)
      elsif self.operator == "nsw"
        return !value_to_test.downcase.start_with?(self.value.downcase)
      elsif self.operator == "regexp"
        return !value_to_test.to_s.match(self.value).nil?
      elsif self.operator == "notregexp"
        return value_to_test.to_s.match(self.value).nil?
      elsif self.operator == "ew"
        return value_to_test.downcase.end_with?(self.value.downcase)
      elsif self.operator == "new"
        return !value_to_test.downcase.end_with?(self.value.downcase)
      elsif self.operator == "nq"
        # The rstrip here is to match how the inequality operator works in MySQL.
        return value_to_test.nil? || value_to_test.downcase.rstrip != self.value.downcase.rstrip
      elsif self.operator == "in"
        # The rstrip here is to match how the IN LIST operator works in MySQL.
        return break_rows(self.value.downcase).include?(value_to_test.downcase.rstrip)
      elsif self.operator == "notin"
        # The rstrip here is to match how the IN LIST operator works in MySQL.
        return !break_rows(self.value.downcase).include?(value_to_test.downcase.rstrip)
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
      elsif self.operator == "gteq"
        return vt >= self_val
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
      elsif self.operator == "dt_regexp" || self.operator == "regexp"
        # This should be in the form of YYYY-mm-dd for dates and YYYY-mm-dd HH:MM for DateTimes
        return !vt.to_s.match(self.value).nil?
      elsif self.operator == "dt_notregexp" || self.operator == "notregexp"
        return vt.to_s.match(self.value).nil?
      elsif self.operator == "pm"
        base_date = self_val.months.ago
        base_date = Date.new(base_date.year,base_date.month,1)
        return (vt < Time.now.to_date) && (vt >= base_date) && !(vt.month == 0.seconds.ago.month && vt.year == 0.seconds.ago.year)
      elsif self.operator == "bma"
        return vt < get_safe_date(d, (Time.zone.now - self_val.months).beginning_of_month.at_midnight)
      elsif self.operator == "ama"
        # Adding 1 day so that we're making sure we're truly comparing that the month is after the given months ago.
        # .ie. If it's currently June..user selects "After 2 months ago", this should mean they get values after April (.ie only from May and beyond).
        return vt >= get_safe_date(d, ((Time.zone.now - self_val.months).end_of_month + 1.day).at_midnight)
      elsif self.operator == "amf"
        # See note above...same situation
        return vt >= get_safe_date(d, ((Time.zone.now + self_val.months).end_of_month + 1.day).at_midnight)
      elsif self.operator == "bmf"
        return vt < get_safe_date(d, (Time.zone.now + self_val.months).beginning_of_month.at_midnight)
      elsif self.operator == "cmo"
        # Includes items that may be in the future, provided that they occur within the current month.
        return vt >= Time.zone.now.beginning_of_month && vt <= Time.zone.now.end_of_month
      elsif self.operator == "pqu"
        # Excludes items from the current quarter.
        return vt >= SearchCriterion.get_previous_quarter_start_date(Time.now, self_val) && vt < SearchCriterion.get_quarter_start_date(SearchCriterion.get_quarter_number(Time.now), Time.now.year)
      elsif self.operator == "cqu"
        # Includes items that may be in the future, provided that they occur within the current quarter.
        return vt >= SearchCriterion.get_quarter_start_date(SearchCriterion.get_quarter_number(Time.now), Time.now.year) && vt < SearchCriterion.get_next_quarter_start_date(Time.now, 1)
      elsif self.operator == "pfcy"
        # Excludes items from the current calendar year.
        return vt >= Date.new(self_val.years.ago.year, 1, 1) && vt < Date.new(Time.now.year, 1, 1)
      elsif self.operator == "cytd"
        # Excludes items from the current year occurring after the current date.  This is labeled specifically as "year to date".
        return vt >= Date.new(Time.now.year, 1, 1) && vt <= Time.now
      end
    elsif d == :boolean
      # The screen does't use 'eq', 'nq' for boolean types, it uses 'null', 'notnull' (evaluated above)
      # So this code doesn't run for searches initiated by the screen.
      truthiness = ["t","true","yes","y"]
      self_val = truthiness.include?(self.value.to_s.downcase)
      if self.operator == "eq"
        return value_to_test == self_val
      elsif self.operator == "nq"
        #testing not equal to true
        if truthiness.include?(self.value.downcase)
          return value_to_test.nil? || !value_to_test
        else
          return value_to_test
        end
      elsif self.operator == "regexp"
        return !value_to_test.to_s.match(self.value).nil?
      elsif self.operator == "notregexp"
        return value_to_test.to_s.match(self.value).nil?
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
      elsif self.operator == "nsw"
        return !value_to_test.to_s.start_with?(self.value.to_s)
      elsif self.operator == "ew"
        return value_to_test.to_s.end_with?(self.value.to_s)
      elsif self.operator == "new"
        return !value_to_test.to_s.end_with?(self.value.to_s)
      elsif self.operator == "nq"
        return value_to_test.nil? || value_to_test!=self_val
      elsif self.operator == "in"
        return break_rows(self.value.downcase).include?(value_to_test.to_s.rstrip)
      elsif self.operator == "notin"
        return !break_rows(self.value.downcase).include?(value_to_test.to_s.rstrip)
      elsif self.operator == "regexp"
        return !value_to_test.to_s.match(self.value).nil?
      elsif self.operator == "notregexp"
        return value_to_test.to_s.match(self.value).nil?
      end
    end
  end

  # A few of the operator types use greater than/less than comparisons.  These work fine when comparing a the base
  # datetime to a DateTime-type database column, but when the database column is a Date, it blows up.  This method
  # ensures that we're comparing like to like.
  def get_safe_date data_type, date
    if data_type == :date
      date = date.to_date
    end
    date
  end

  def number_value data_type, value
    sval = (value.blank? || !is_a_number(value) ) ? "0" : value
    data_type==:integer ? sval.to_i : BigDecimal(sval.to_s)
  end

  def is_a_number val
    begin Float(val) ; true end rescue false
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

    # We're rstrip'ing here to emulate the IN list handling of MySQL (which trims trailing whitespace before doing comparisons)
    # The strip is to remove any trailing newlines from the initial list, without which we'd possibly get a extra blank value added
    # to the comparison list
    list = val.strip.split(/\r?\n/).collect {|line| line.rstrip}

    # If val was blank to begin with, we'll get a zero length array back (split returns a blank array on blank strings),
    # which causes the query to generate an in list like "()", which bombs, so we'll just put a blank value back in the array.
    # Standard ActiveRecord where clauses handle this ok, but our search_query building doesn't so much.
    if list.length == 0
      list = [""]
    end
    list
  end

end
