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
      return "#{cleaned[0..3]}.#{cleaned[4..5]}.#{cleaned[6..7]}.#{cleaned[8..9]}"
    else
      return "#{cleaned[0..3]}.#{cleaned[4..5]}.#{cleaned[6..7]}.#{cleaned[8..(cleaned.length-1)]}"
    end 
  end
end
