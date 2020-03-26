# The idea around this module is a series of methods that extract 
# data based around 1 indexed line positions, this way it is easier
# to confirm field positions against a spec provided by the client, rather
# than having all the positions be off by one when extracting the 
# data using 0 indexed Array positions for the strings.

module OpenChain; module CustomHandler; module FixedPositionParserSupport
  extend ActiveSupport::Concern

  # Extracts a string from the given line.
  # line - the line to extract data from
  # spec_range - Can be a range (1...5) to extract multiple chars or an integer to extract a single char.
  # trim_whitespace - if true, will string leading / trailing whitespace
  def extract_string line, spec_range, trim_whitespace: true
    start_pos = nil
    end_pos = nil
    if spec_range.is_a?(Range)
      start_pos = spec_range.begin - 1
      end_pos = spec_range.end - 1
    elsif spec_range.is_a?(Numeric)
      start_pos = spec_range.to_i - 1
      end_pos = spec_range.to_i - 1
    else
      raise "Invalid line position given #{spec_range}."
    end

    v = line[start_pos..end_pos].to_s
    trim_whitespace ? v.strip : v
  end

  # Extracts an integer from the given line.
  # line - the line to extract data from
  # spec_range - Can be a range (1...5) to extract multiple chars or an integer to extract a single char.
  # rounding_mode - If the value in the spec_range represents decimal values, rounding_mode can be used to 
  # tell how exactly you want to round the value to the nearest integer value.  Defaults to BigDecimal::ROUND_HALF_UP
  def extract_integer line, spec_range, rounding_mode: BigDecimal::ROUND_HALF_UP
    v = extract_string(line, spec_range)
    return nil if v.blank?
    # Return nil if there's non-digit, decimal or negative value present in the string
    return nil if v =~ /[^\d\-\.]/

    # For some fields, there's going to be leading zeros in the numeric value...this causes the Integer 
    # initializer to interpret the value as Octal, thus giving a completely unexpected number.
    # In order words, we need to strip leading zeros from the value
    while (v.starts_with?("0"))
      v = v[1..-1]
    end

    # The reason for parsing with BigDecimal is there might be a decimal point in the data, if there is
    # we don't want the parse to fail (which it will with an Integer parse)..we'll just to_i the result.
    BigDecimal(v).round(0, rounding_mode).to_i rescue nil
  end

  # Extracts an decimal value from the given line.
  #
  # line - the line to extract data from
  # spec_range - Can be a range (1...5) to extract multiple chars or an integer to extract a single char.
  # decimal_places - the number of decimal places to retain from the decimal value.
  # rounding_mode - rounding_mode can be used to tell how exactly you want to round the value to the number
  # of decimal_places given.  Defaults to BigDecimal::ROUND_HALF_UP
  def extract_decimal line, spec_range, decimal_places:, rounding_mode: BigDecimal::ROUND_HALF_UP
    v = extract_string(line, spec_range)
    return nil if v.blank?

    BigDecimal(v).round(decimal_places, rounding_mode) rescue nil
  end

  # Extract a decimal value from a line where the number of decimal places is an implied value.  This means
  # that the string data will look like 12345 and if there are 2 implied decimal places then the value returned would 
  # be 123.45
  #
  # line - the line to extract data from
  # spec_range - Can be a range (1...5) to extract multiple chars or an integer to extract a single char.
  # decimal_places - the number of implied decimal places to assume from the given data
  def extract_implied_decimal line, spec_range, decimal_places:
    # This seems a little weird, but all the actual data we'll 
    # get in the Catair will have implied decimal places, so we
    # can parse the value as an integer (getting the benefit of 
    # the leading zero stripping) and then inject the 
    # decimal place in after the fact
    int = extract_integer(line, spec_range).to_s
    return nil if int.blank?

    # Inject the decimal back in
    if decimal_places > 0
      # add leading zeros back on until the length of the string is more than the decimal places
      while(int.length < decimal_places)
        int = "0" + int
      end

      int = int[0..(int.length - (decimal_places + 1))] + "." + int[(int.length - decimal_places)..-1]
    end

    BigDecimal(int)
  end

  # Extract a date value from a given line
  #
  # line - the line to extract data from
  # spec_range - A range (1..5)
  # date_format - The format to use to parse the date string (default: %Y%m%d )
  def extract_date line, spec_range, date_format: "%Y%m%d"
    v = extract_string(line, spec_range)
    return nil if v.blank?
    Date.strptime(v, date_format) rescue nil
  end

  # Extract a date value from a given line
  #
  # line - the line to extract data from
  # spec_range - A range (1..5)
  # date_format - The format to use to parse the date string (default: %Y%m%d%H%M )
  # time_zone: The timezone to use for the date to be relative to.  Should be an ActiveSupport::TimeZone instance.
  #            Defaults to Time.zone
  def extract_datetime line, spec_range, datetime_format: "%Y%m%d%H%M", time_zone: Time.zone
    v = extract_string(line, spec_range)
    return nil if v.blank?

    time_zone = ActiveSupport::TimeZone[time_zone] if time_zone.is_a?(String)
    
    # All the following stupidity is to ensure the datetime given represents the moment in time in the
    # given timezone...In Rails 5, this all can just be replaced by Time.zone.strptime(v, datetime_format)
    #
    # This is all to ensure that when we say "2020-03-18 12:30" is the time in US Eastern timezone that
    # we're returning an TimeWithZone object that says `2020-03-18 12:30 -04:00`
    if (datetime_format =~ /%z/i).nil?
      append_offset = true
      datetime_format += " %z"
    end

    v += " #{time_zone.now.formatted_offset(false)}" if append_offset
    begin
      val = Time.strptime v, datetime_format
      return val.in_time_zone(time_zone)
    rescue
      return nil
    end
  end

  # Extract a boolean from a given line.  Only returns true if the value matches
  # one of the given truthy_value strings.
  # 
  # line - the line to extract data from
  # spec_range - Can be a range (1...5) to extract multiple chars or an integer to extract a single char.
  # truthy_values - An Array of all the string values that should evaluate to true, every other value will return
  # false.
  # upcase_values - If true, the string extracted from the line will be upcased before checking boolean values. Default = true
  # blank_string_returns_nil - If true, nil is returned (rather than false) if the extracted string is blank.  Default = false
  def extract_boolean line, spec_range, truthy_values: ["Y", "YES", "1", "TRUE", "T"], upcase_values: true, blank_string_returns_nil: false
    v = extract_string(line, spec_range)
    if v.blank?
      return nil if blank_string_returns_nil

      v = ""
    else
      v.upcase! if upcase_values
    end

    truthy_values.include? v
  end

end; end; end