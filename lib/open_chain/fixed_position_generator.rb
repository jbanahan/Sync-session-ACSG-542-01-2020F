module OpenChain; class FixedPositionGenerator
  include ActionView::Helpers::NumberHelper # in Rails 4.x this should change to ActiveSupport::NumberHelper

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

  def str s, len, right_justify = false, force_truncate = false
    v = nil
    if !s.nil?
      v = encode_string(replace_newlines(s.to_s))

      if v.length > len
        raise "String '#{v}' is longer than #{len} characters" if @opts[:exception_on_truncate] && !force_truncate
        v = v[0,len]
      end
    else
      v = ''
    end

    if right_justify
      v = v.rjust(len,@opts[:pad_char])
    else
      v = v.ljust(len,@opts[:pad_char])
    end

    v
  end

  # makes a padded, right justified value with decimals
  # .num(5,6,2) -> '  5.00'
  # This method always raises an exception on truncation since truncating numbers is really misleading
  #
  # Opts can include:
  # :round_mode - The BigDecimal::ROUND_* mode to use for rounding to the provided precision
  # :numeric_strip_decimals - if true, removes decimal place period from output (can be provided globally via constructor opts too)
  # :numeric_pad_char - if present, uses the value defined as the pad char (can be provided globally via constructor opts too)
  # :numeric_left_align - if true, number will be left aligned (can be provided globally via constructor opts too)
  #
  def num number, width, decimal_positions=0, opts={}
    inner_opts = @opts.merge({round_mode: BigDecimal::ROUND_HALF_UP}).merge opts

    s = ''
    if number.nil?
      s = ''
    else
      # Round first since number_with_precision doesn't allow for specifiying the rounding mode
      value = BigDecimal(number.to_s).round(decimal_positions, inner_opts[:round_mode])
      # The value should already be rounded, so there should be no additional rounding being done 
      # by the number_with_precision call here, instead precision is here for display purposes only
      # Only use en locale so we don't end up with different decimal point value if somehow our default locale 
      # is changed (ie 1.00 -> 1,00)

      if value.zero? && inner_opts[:numeric_no_pad_zero]
        precision_opts = {precision: 0, locale: :en}
      else
        precision_opts = {precision: decimal_positions, locale: :en}
      end

      
      precision_opts[:strip_insignificant_zeros] = true if opts[:numeric_strip_trailing_zeros] == true

      s = number_with_precision(value, precision_opts)

      s.gsub! '.', '' if inner_opts[:numeric_strip_decimals]
    end

    r = inner_opts[:numeric_left_align] ? s.ljust(width, inner_opts[:numeric_pad_char]) : s.rjust(width, inner_opts[:numeric_pad_char])

    raise "Number #{r}#{inner_opts[:numeric_strip_decimals] ? " (#{decimal_positions} implied decimals) " : " "}doesn't fit in #{width} character field" if r.size > width
    r
  end

  def date d, format_override=nil, timezone_override = nil
    f = format_override.blank? ? @opts[:date_format] : format_override
    v = nil
    if d.nil?
      v = ''.ljust(Time.now.strftime(f).length, @opts[:blank_date_fill_char])
    else
      if d.respond_to?(:in_time_zone)
        # Use the override, if given, fall back to opts if there, else fall back to Time.zone setting
        tz = timezone_override ? timezone_override : (@opts[:output_timezone] ? @opts[:output_timezone] : Time.zone )
        d = d.in_time_zone tz if tz
      end

      v = d.strftime(f)
    end
    v
  end

  private 
  def has_decimal? number
    number.to_s.match(/\./)
  end
  def replace_newlines s
    s.gsub(/(?:(?:\r\n)|\n|\r)/,@opts[:line_break_replace_char])
  end

  def encode_string s
    if @output_encoding
      s.encode @output_encoding, replace: @opts[:string_output_encoding_replacement_char], invalid: :replace, undef: :replace
    else
      s
    end
  end
end; end
