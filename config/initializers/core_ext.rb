String.class_eval do
  #returns a copy of the string with decimals in the right place to look like a commonly formatted HTS number
  def hts_format
    return String.new self unless self.match(/^[0-9\. ]*$/) #if not potentially an HTS, return a copy without modification
    cleaned = self.to_s.gsub(/[^0-9]/,"") #strip out extra characters
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
end

Exception.class_eval do
  #emails the exception to bug@aspect9.com.  
  #Delayed option is ignored when attachment_paths are included since we can't be garunteed that the attachments 
  #will be on the same server as the delayed_job worker
  def email_me messages=[], attachment_paths=[], delayed=true
    if delayed && attachment_paths.blank?
      OpenMailer.delay.send_generic_exception(self,messages,self.message,self.backtrace)
    else
      OpenMailer.send_generic_exception(self,messages,self.message,self.backtrace,attachment_paths).deliver
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
