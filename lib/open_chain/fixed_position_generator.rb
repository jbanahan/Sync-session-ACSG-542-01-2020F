module OpenChain; class FixedPositionGenerator
  def initialize opts={}
    @opts = {
      exception_on_truncate:false,pad_char:' ',
      line_break_replace_char:' ',
      date_format:'%Y%m%d',
      output_timezone: nil
    }
    @opts.merge! opts
  end

  def str s, len, right_justify = false, force_truncate = false
    return ''.ljust(len,@opts[:pad_char]) if s.nil?
    r = replace_newlines s.to_s
    if r.length > len
      raise "String '#{r}' is longer than #{len} characters" if @opts[:exception_on_truncate] && !force_truncate
      return r[0,len]
    end
    if right_justify
      return r.rjust(len,@opts[:pad_char])
    else
      return r.ljust(len,@opts[:pad_char])
    end
  end

  #makes a 0 padded, right justified value with implied decimals
  # .num(5,6,2) # 000500
  # Opts can include :round_mode for BigDecimal conversions
  #
  # This always raises an exception on truncation since truncating numbers is really misleading
  def num number, width, decimal_positions=0, opts={}
    inner_opts = {round_mode:BigDecimal::ROUND_HALF_UP}
    inner_opts.merge! opts
    s = ''
    if number.nil?
      s = ''
    elsif has_decimal?(number)
      n_str = number.to_s
      n_dec = n_str.split('.').last
      if(n_dec.size > decimal_positions)
        n_str = BigDecimal(n_str).round(decimal_positions,inner_opts[:round_mode]).to_s
        n_dec = decimal_positions < 1 ? '' : n_str.split('.').last
      end
      n_dec << '0' while n_dec.size < decimal_positions
      s = "#{n_str.split('.').first}#{n_dec}"      
    else
      decimal_holder = Array.new(decimal_positions,'0').join('')
      s = "#{number}#{decimal_holder}"
    end
    r = s.rjust(width,'0')
    raise "Number #{r} (#{decimal_positions} implied decimals) doesn't fit in #{width} character field" if r.size > width
    r
  end

  def date d, format_override=nil, timezone_override = nil
    f = format_override.blank? ? @opts[:date_format] : format_override
    return ''.ljust(Time.now.strftime(f).length) if d.nil?
    if d.respond_to?(:in_time_zone)
      # Use the override, if given, fall back to opts if there, else fall back to Time.zone setting
      tz = timezone_override ? timezone_override : (@opts[:output_timezone] ? @opts[:output_timezone] : Time.zone )
      d = d.in_time_zone tz if tz
    end

    d.strftime(f)
  end

  private 
  def has_decimal? number
    number.to_s.match(/\./)
  end
  def replace_newlines s
    s.gsub(/(?:(?:\r\n)|\n|\r)/,@opts[:line_break_replace_char])
  end
end; end
