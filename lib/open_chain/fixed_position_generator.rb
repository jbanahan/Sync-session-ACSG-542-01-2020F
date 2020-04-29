module OpenChain; class FixedPositionGenerator
  include ActionView::Helpers::NumberHelper # in Rails 4.x this should change to ActiveSupport::NumberHelper

  class FixedPositionGeneratorError < StandardError; end

  class DataTruncationError < FixedPositionGeneratorError; end

  def initialize opts={}
    @opts = {
      exception_on_truncate:false,
      pad_char:' ',
      line_break_replace_char:' ',
      date_format:'%Y%m%d',
      output_timezone: nil,
      numeric_pad_char: ' ',
      blank_date_fill_char: ' ',
      string_output_encoding: '',
      string_output_encoding_replacement_char: '?',
    }.merge! opts

    if !@opts[:string_output_encoding].blank?
      @output_encoding = Encoding.find(@opts[:string_output_encoding])
    else
      @output_encoding = nil
    end
  end

  #
  # This method is sticking around for backwards compatability...use #string instead
  #
  def str s, len, right_justify = false, force_truncate = false
    string(s, len, justification: (right_justify ? :right : :left), force_truncate: force_truncate)
  end

  def string s, max_length, pad_string: true, justification: :left, force_truncate: false, pad_char: nil, exception_on_truncate: nil, encoding: nil, encoding_replacment_char: nil
    v = nil
    if !s.nil?
      v = encode_string(replace_newlines(s.to_s), encoding, encoding_replacment_char)

      if v.length > max_length
        raise DataTruncationError, "String '#{v}' is longer than #{max_length} characters" if opts_val(exception_on_truncate, :exception_on_truncate) && !force_truncate
        v = v[0, max_length]
      end
    else
      v = ''
    end

    # Yes, disabling padding doesn't make sense when used strictly in a fixed width output, but this
    # class has enough value in truncation detection and encoding output that it can be used in other
    # output scenarios (like validating xml lengths into a system we know max lengths for .ie Kewill)
    if pad_string
      v = pad(v, max_length, justification, pad_char, :pad_char)
    end

    v
  end

  #
  # This method is sticking around for backwards compatability...use #number instead
  #
  def num n, width, decimal_positions=0, opts={}
    # The defaults here are just copied from the defaults defined below on the number method.
    inner_opts = @opts.merge({round_mode: BigDecimal::ROUND_HALF_UP, numeric_strip_trailing_zeros: false, numeric_no_pad_zero: false}).merge opts

    number(n, width, decimal_places: decimal_positions, round_mode: inner_opts[:round_mode], strip_trailing_zeros: inner_opts[:numeric_strip_trailing_zeros], strip_decimals: inner_opts[:numeric_strip_decimals],
           justification: (inner_opts[:numeric_left_align] ? :left : :right), pad_zero: inner_opts[:numeric_no_pad_zero], pad_char: inner_opts[:numeric_pad_char])
  end

  # makes a padded, right justified value with decimals
  # .num(5,6, decimal_places: 2) -> '  5.00'
  # This method always raises an exception on truncation since truncating numbers is really misleading
  #
  # Opts can include:
  # :decimal_places - Adjust the number of decimal places to leave before rounding. (Zero by default)
  # :round_mode - The BigDecimal::ROUND_* mode to use for rounding to the provided precision (deafults to ROUND_HALF_UP)
  # :strip_decimals - if true, removes decimal place period from output (can be provided globally via constructor opts too)
  # :pad_char - if present, uses the value defined as the pad char (can be provided globally via constructor opts too)
  # :justification - if value of :left is used, number will be left aligned, otherwise, number is right justified.
  # :pad_string - If false, no padding will be done to decimals that are smaller in width than the max field width parameter
  # :pad_zero - If true, a value of zero will be left as zero and not padded out with zeros for the decimal places.
  # :strip_trailing_zeros - If true, all insiginificant zeros will be removed from the output string.
  # :max_value - If given, an error is raised if value is greater than given max value
  # :exclude_decimal_from_length_validation - If true, width validation for resulting string will not consider the decimal point.
  def number n, width, decimal_places: 0, round_mode: BigDecimal::ROUND_HALF_UP, strip_trailing_zeros: false, strip_decimals: nil, pad_string: true, pad_char: nil, justification: :right, pad_zero: false, max_value: nil, exclude_decimal_from_length_validation: false
    s = ''
    if n.nil?
      s = ''
    else
      # Round first since number_with_precision doesn't allow for specifiying the rounding mode
      value = BigDecimal(n.to_s).round(decimal_places, round_mode)

      if max_value
        raise DataTruncationError, "Number #{value} cannot be greater than #{max_value}." if value > max_value
      end

      # The value should already be rounded, so there should be no additional rounding being done
      # by the number_with_precision call here, instead precision is here for display purposes only
      # Only use en locale so we don't end up with different decimal point value if somehow our default locale
      # is changed (ie 1.00 -> 1,00)

      if value.zero? && pad_zero
        precision_opts = {precision: 0, locale: :en}
      else
        precision_opts = {precision: decimal_places, locale: :en}
      end

      precision_opts[:strip_insignificant_zeros] = true if strip_trailing_zeros == true

      s = number_with_precision(value, precision_opts)

      s.gsub! '.', '' if opts_val(strip_decimals, :numeric_strip_decimals)
    end

    if pad_string
      r = pad(s, width, justification, pad_char, :numeric_pad_char)
    else
      r = s
    end

    if exclude_decimal_from_length_validation
      length = r.gsub(".", "").length
    else
      length = r.length
    end

    raise DataTruncationError, "Number #{r}#{strip_decimals ? " (#{decimal_places} implied decimals) " : " "}doesn't fit in #{width} character field" if length > width
    r
  end

  def date d, format_override=nil, timezone_override = nil
    datetime(d, date_format: format_override, timezone: timezone_override)
  end

  def datetime d, date_format: nil, timezone: nil, max_length: nil, justification: :right, pad_char: nil
    format = opts_val(date_format, :date_format)

    v = nil
    if d.nil?
      v = ''.ljust(Time.now.strftime(format).length, opts_val(pad_char, :blank_date_fill_char))
    else
      if d.respond_to?(:in_time_zone)
        # Use the override, if given, fall back to opts if there, else fall back to Time.zone setting
        tz = opts_val(timezone, :output_timezone).presence || Time.zone
        d = d.in_time_zone tz if tz
      end

      v = d.strftime(format)
    end

    if max_length.to_i > 0
      v = pad(v, max_length, justification, pad_char, :blank_date_fill_char)
    end

    v
  end

  private

  def opts_val val, opts_key
    val.nil? ? @opts[opts_key] : val
  end

  def has_decimal? number
    number.to_s.match(/\./)
  end
  def replace_newlines s
    s.gsub(/(?:(?:\r\n)|\n|\r)/, @opts[:line_break_replace_char])
  end

  def encode_string s, enc, replacement_char
    encoding = enc || @output_encoding
    if encoding.is_a?(String)
      encoding = Encoding.find(encoding)
    end

    replace = opts_val(replacement_char, :string_output_encoding_replacement_char)
    if encoding
      s.encode encoding, replace: replace, invalid: :replace, undef: :replace
    else
      s
    end
  end

  def pad value, max_length, justification, pad_char, pad_char_type
    if justification == :right
      return value.rjust(max_length, opts_val(pad_char, pad_char_type))
    else
      return value.ljust(max_length, opts_val(pad_char, pad_char_type))
    end
  end
end; end
