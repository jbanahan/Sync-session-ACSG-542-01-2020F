ActiveSupport::TimeZone.class_eval do
  # parse a date in "01/28/2008 04:27am" format
  def parse_us_base_format str
    raise ArgumentError unless str.length==18
    mon = str[0, 2].to_i
    day = str[3, 2].to_i
    year = str[6, 4].to_i
    meridian = str[16, 2].downcase
    hour = str[11, 2].to_i
    hour += 12 if meridian == 'pm' && hour!=12
    hour = 0 if meridian == 'am' && hour==12
    min = str[14, 2].to_i

    parse "#{year}-#{mon}-#{day} #{hour}:#{min}"
  end
end
String.class_eval do
  # returns a copy of the string with decimals in the right place to look like a commonly formatted HTS number
  def hts_format
    return String.new self unless TariffRecord.validate_hts(self) # if not potentially an HTS, return a copy without modification
    cleaned = TariffRecord.clean_hts(self)
    case cleaned.length # format
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

  # Returns true for any value considered true by ActiveRecord when coercing user data to the database
  # False for everything else
  TRUE_VALUES = [true, 1, '1', 't', 'T', 'true', 'TRUE', 'on', 'ON'].to_set.freeze

  def to_boolean
    TRUE_VALUES.include?(self.upcase)
  end

  # Like String#strip but removes a wider variety of characters, including non-breaking space
  def strip_all_whitespace
    self.gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")
  end
end

class SerializableNoMethodError < StandardError; end;

Exception.class_eval do
  # logs the exception to the database and emails it to bug@vandegriftinc.com
  def log_me messages=[], attachment_paths=[], send_now=false
    return unless MasterSetup.connection.table_exists? 'error_log_entries'

    # Messages is expected to be an array here, so ensure it is
    messages = Array.wrap(messages)
    e = ErrorLogEntry.create_from_exception self, messages
    msgs = messages.blank? ? [] : messages.dup
    msgs << "Error Database ID: #{e.id}"
    if e.email_me?
      if attachment_paths.blank? && !send_now
        # Rails can't serialize classes, so just send the exception class name itself, which is really all the actual output utilizes anyway
        # if all the params are fed to the method
        OpenMailer.send_generic_exception(self.class.to_s, msgs, self.message, self.backtrace).deliver_later
      else
        OpenMailer.send_generic_exception(self.class.to_s, msgs, self.message, self.backtrace, Array.wrap(attachment_paths)).deliver_now
      end
    end
  end
end

module Spreadsheet

  module Excel
    class Row
      alias_method :original_array, :[]

      def [] idx, len=nil
        r = len.nil? ? original_array(idx) : original_array(idx, len)
        !r.nil? && r.is_a?(Float) && r.to_i==r ? r.to_i : r
      end
    end
  end

  class Row
    alias_method :original_array, :[]

    def [] idx, len=nil
      r = len.nil? ? original_array(idx) : original_array(idx, len)
      !r.nil? && r.is_a?(Float) && r.to_i==r ? r.to_i : r
    end
  end
end
