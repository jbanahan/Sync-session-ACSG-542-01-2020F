ActiveSupport::TimeZone.class_eval do
  #parse a date in "01/28/2008 04:27am" format
  def parse_us_base_format str
    raise ArgumentError unless str.length==18
    mon = str[0,2].to_i
    day = str[3,2].to_i
    year = str[6,4].to_i
    meridian = str[16,2].downcase
    hour = str[11,2].to_i
    hour += 12 if meridian == 'pm' && hour!=12
    hour = 0 if meridian == 'am' && hour==12
    min = str[14,2].to_i

    parse "#{year}-#{mon}-#{day} #{hour}:#{min}"
  end
end
String.class_eval do
  #returns a copy of the string with decimals in the right place to look like a commonly formatted HTS number
  def hts_format
    return String.new self unless TariffRecord.validate_hts(self) #if not potentially an HTS, return a copy without modification
    cleaned = TariffRecord.clean_hts(self)
    case cleaned.length #format
    when 0..5
      return cleaned
    when 6
      return "#{cleaned[0..3]}.#{cleaned[4..5]}"
    when 7
      return "#{cleaned[0..3]}.#{cleaned[4..6]}"
    when 8
      return "#{cleaned[0..3]}.#{cleaned[4..5]}.#{cleaned[6..7]}"
    when 9
      return "#{cleaned[0..3]}.#{cleaned[4..5]}.#{cleaned[6..8]}"
    when 10
      return "#{cleaned[0..3]}.#{cleaned[4..5]}.#{cleaned[6..9]}"
    else
      return "#{cleaned[0..3]}.#{cleaned[4..5]}.#{cleaned[6..7]}.#{cleaned[8..(cleaned.length-1)]}"
    end 
  end

  def to_boolean
    ActiveRecord::ConnectionAdapters::Column.value_to_boolean self
  end
end

# Backporting Array#deep_dup, Hash#deep_dup, Object#deep_dup from Rails 4 to 3.2 (.ie remove this when we move to Rails 4)
# In Rails 3.x, if you deep_dup a Hash with an array value, the array contents are not duped.  So if you have a hash inside that
# array (like when posting nested AR attributes) and you clone it, and then modify the hash inside the cloned array, both 
# the original and the cloned hash reflect the changes.
# 
# In other words, without the patch, the following happens: 
# 
# orig = {'key' => [{'inner_key' => 'inner_value'}]}
# orig_dupe = orig.deep_dup
# orig_dupe['key'][0]['new_key'] = 'new_value'
# orig['key'][0]['new_key'] # => "new_value" !!!! WTF - Should be nil !!!!

Array.class_eval do
  def deep_dup
    map { |it| it.deep_dup }
  end
end

Hash.class_eval do
  def deep_dup
    each_with_object(dup) do |(key, value), hash|
      hash[key.deep_dup] = value.deep_dup
    end
  end
end

Object.class_eval do
  def deep_dup
    duplicable? ? dup : self
  end
end

class SerializableNoMethodError < StandardError; end;

Exception.class_eval do
  #logs the exception to the database and emails it to bug@vandegriftinc.com
  def log_me messages=[], attachment_paths=[], send_now=false
    return unless MasterSetup.connection.table_exists? 'error_log_entries'
    e = ErrorLogEntry.create_from_exception self, messages
    msgs = messages.blank? ? [] : messages.dup
    msgs << "Error Database ID: #{e.id}"
    if e.email_me?
      if attachment_paths.blank? && !send_now
        # Psych (via Delayed Jobs) has an issue serializing NoMethodErrors due to the NameError object used inside NoMethodError.
        # This is a workaround for dealing w/ that since the issue has been open in Psych for over a year with no plans for resolution.
        if self.is_a? NoMethodError
          error = SerializableNoMethodError.new self.message
          error.set_backtrace self.backtrace
          error.log_me messages, attachment_paths, send_now
        else
          OpenMailer.delay.send_generic_exception(self,msgs,self.message,self.backtrace)
        end
      else
        OpenMailer.send_generic_exception(self,msgs,self.message,self.backtrace,attachment_paths).deliver
      end
    end
  end
end

module Spreadsheet

  module Excel
    class Row
      alias_method :original_array, :[]

      def [] idx, len=nil
        r = len.nil? ? original_array(idx) : original_array(idx,len)
        !r.nil? && r.is_a?(Float) && r.to_i==r ? r.to_i : r
      end
    end
  end

  class Row 
    alias_method :original_array, :[]

    def [] idx, len=nil
      r = len.nil? ? original_array(idx) : original_array(idx,len)
      !r.nil? && r.is_a?(Float) && r.to_i==r ? r.to_i : r
    end
  end
end
