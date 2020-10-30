class CriterionOperator
  attr_reader :key, :label, :relative_to_start_of_day, :relative_to_user_timezone

  def initialize(key, query_string, label, opts = {})
    @key = key
    @query_string = query_string
    @label = label
    @relative_to_start_of_day = opts[:relative_to_start_of_day]
    @relative_to_user_timezone = opts[:relative_to_user_timezone]
  end

  def query_string(field_name, data_type, include_empty = false)
    if @relative_to_user_timezone && data_type == :datetime
      mysql_user_time_zone = Time.zone.tzinfo.name
      query = @query_string.gsub /_fn_/, "convert_tz(#{field_name}, 'GMT', '#{mysql_user_time_zone}')"
    else
      # This code is test cased in the search_criterion's test case
      query = @query_string.gsub(/_fn_/, field_name)
    end

    # Any field that requires be centered around the current date needs to have the
    # date based around the user's timezone.  In other words, if it's 11 PM and user is in
    # New York, the current date to use to center the report around is 1 day prior to a user
    # in London (GMT).  Time.zone is set according to user's pref for searches (both front and backend).
    if @relative_to_start_of_day
      # If the field is a date value, we need to make sure we're using the user's current time
      base_line_date = Time.zone.now.at_midnight

      # If the field is a datetime and the field requires baselining the date to day start/end we need to make sure the
      # baseline of the day/month start/end coincides with the start of the day in the user's timezone.
      if data_type == :datetime
        base_line_date = base_line_date.in_time_zone "UTC"
      end

      query = query.gsub("_CURRENT_DATE_", "'#{base_line_date.strftime("%Y-%m-%d %H:%M:%S")}'")
    end

    if include_empty
      query = "#{query} OR #{field_name} IS NULL"

      if character_based_data_type? data_type
        # We'll consider having nothing but whitespace as being empty too
        query += " OR LENGTH(TRIM(#{field_name})) = 0"
      elsif numeric_data_type? data_type
        # We'll consider equaling zero as being empty too
        query += " OR #{field_name} = 0"
      end
      query = "#{query}"
    end

    query
  end

  OPERATORS = [
    new("eq", "_fn_ = ?", "Equals"),
    new("eqfdec", "_fn_ = ?", "Decimal Equals"),
    new("nqfdec", "_fn_ <> ?", "Decimal Not Equal"),
    new("gtfdec", "_fn_ < ?", "Decimal Greater Than"),
    new("ltfdec", "_fn_ > ?", "Decimal Less Than"),
    new("gt", "_fn_ > ?", "Greater Than"),
    new("gteq", "_fn_ >= ?", "Greater Than (Inclusive)"),
    new("lt", "_fn_ < ?", "Less Than"),
    new("co", "_fn_ LIKE ?", "Contains"),
    new("nc", "NOT _fn_ LIKE ?", "Doesn't Contain"),
    new("sw", "_fn_ LIKE ?", "Starts With"),
    new("ew", "_fn_ LIKE ?", "Ends With"),
    new("nsw", "_fn_ NOT LIKE ?", "Does Not Start With"),
    new("new", "_fn_ NOT LIKE ?", "Does Not End With"),
    new("regexp", "_fn_ REGEXP ?", "Regex"),
    new("notregexp", "_fn_ NOT REGEXP ?", "Not Regex"),
    new("dt_regexp", "_fn_ REGEXP ?", "Regex", relative_to_user_timezone: true),
    new("dt_notregexp", "_fn_ NOT REGEXP ?", "Not Regex", relative_to_user_timezone: true),
    new("null", "_fn_ IS NULL OR trim(_fn_)=''", "Is Empty"),
    new("notnull", "_fn_ IS NOT NULL AND NOT trim(_fn_)=''", "Is Not Empty"),
    new("bda", "_fn_ < DATE_ADD(_CURRENT_DATE_, INTERVAL -? DAY)", "Before _ Days Ago", relative_to_start_of_day: true),
    new("ada", "_fn_ >= DATE_ADD(_CURRENT_DATE_, INTERVAL -? DAY)", "After _ Days Ago", relative_to_start_of_day: true),
    new("adf", "_fn_ >= DATE_ADD(_CURRENT_DATE_, INTERVAL ? DAY)", "After _ Days From Now", relative_to_start_of_day: true),
    new("bdf", "_fn_ < DATE_ADD(_CURRENT_DATE_, INTERVAL ? DAY)", "Before _ Days From Now", relative_to_start_of_day: true),
    new("bma", "_fn_ < CAST(DATE_FORMAT(DATE_ADD(_CURRENT_DATE_, INTERVAL -? MONTH) ,'%Y-%m-01 %H:%i:%S') as DATETIME)", "Before _ Months Ago", relative_to_start_of_day: true),
    # The (? - 1) makes the value relative to the start of the month after the user is expecting..so if the current month is June and the user selected two months
    # ago, this makes the query run like 'field >= XXXX-05-01'.  Including only things in or after May.
    new("ama", "_fn_ >= CAST(DATE_FORMAT(DATE_ADD(_CURRENT_DATE_, INTERVAL -(? - 1) MONTH) ,'%Y-%m-01 %H:%i:%S') as DATETIME)", "After _ Months Ago", relative_to_start_of_day: true),
    # The (? + 1) makes the value relative to the start of the month after the user is expecting..so if the current month is June and the user selected two months
    # from now, this makes the query run like 'field >= XXXX-09-01'.  Including only things in or after September.
    new("amf", "_fn_ >= CAST(DATE_FORMAT(DATE_ADD(_CURRENT_DATE_, INTERVAL (? + 1) MONTH) ,'%Y-%m-01 %H:%i:%S') as DATETIME)", "After _ Months From Now", relative_to_start_of_day: true),
    new("bmf", "_fn_ < CAST(DATE_FORMAT(DATE_ADD(_CURRENT_DATE_, INTERVAL ? MONTH) ,'%Y-%m-01 %H:%i:%S') as DATETIME)", "Before _ Months From Now", relative_to_start_of_day: true),
    new("nq", "(_fn_ IS NULL OR NOT _fn_ = ?)", "Not Equal To"),
    new("in", "(_fn_ IN (?))", "One Of"),
    new("notin", "(_fn_ NOT IN (?))", "Not One Of"),
    new("pm", "(_fn_ >= CAST(DATE_FORMAT(DATE_ADD(_CURRENT_DATE_,INTERVAL -? MONTH) ,\"%Y-%m-01\") as DATE) and _fn_ < NOW() and NOT (MONTH(_fn_) = MONTH(_CURRENT_DATE_) AND YEAR(_fn_) = YEAR(_CURRENT_DATE_)))", "Previous _ Months", relative_to_user_timezone: true, relative_to_start_of_day: true),
    new("cmo", "MONTH(_fn_) = MONTH(_CURRENT_DATE_) AND YEAR(_fn_) = YEAR(_CURRENT_DATE_)", "Current Month", relative_to_start_of_day: true),
    new("pqu", "_fn_ >= (DATE_ADD(MAKEDATE(YEAR(CURDATE()), 1) + INTERVAL QUARTER(CURDATE()) QUARTER - INTERVAL 1 QUARTER, INTERVAL -? QUARTER)) and _fn_ < (MAKEDATE(YEAR(CURDATE()), 1) + INTERVAL QUARTER(CURDATE()) QUARTER - INTERVAL 1 QUARTER)", "Previous _ Quarters", relative_to_start_of_day: true),
    new("cqu", "_fn_ >= (MAKEDATE(YEAR(CURDATE()), 1) + INTERVAL QUARTER(CURDATE()) QUARTER - INTERVAL 1 QUARTER) AND _fn_ < (MAKEDATE(YEAR(now()), 1) + INTERVAL QUARTER(now()) QUARTER)", "Current Quarter", relative_to_start_of_day: true),
    new("pfcy", "_fn_ >= DATE_ADD(MAKEDATE(YEAR(_CURRENT_DATE_),1),INTERVAL -? YEAR) AND YEAR(_fn_) < YEAR(_CURRENT_DATE_)", "Previous _ Full Calendar Years", relative_to_start_of_day: true),
    new("cytd", "YEAR(_fn_) = YEAR(_CURRENT_DATE_) AND _fn_ < _CURRENT_DATE_", "Current Year To Date", relative_to_start_of_day: true)
  ]

  def self.find_by_key(key)
    OPERATORS.each {|o| return o if o.key==key}
    nil
  end

  singleton_class.send(:alias_method, :by_key, :find_by_key)

  private
    def character_based_data_type? data_type
      return [:text, :string].include? data_type
    end

    def numeric_data_type? data_type
      return [:integer, :decimal, :fixnum].include? data_type
    end
end
