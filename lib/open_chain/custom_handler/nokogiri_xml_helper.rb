require 'nokogiri'

module OpenChain; module CustomHandler; module NokogiriXmlHelper
  def est_time_str t
    ActiveSupport::TimeZone["Eastern Time (US & Canada)"].at(t.to_i).strftime("%Y-%m-%d %H:%M %Z")
  end

  #get element text
  # if force_blank_string then send "" instead of null
  def et parent, element_name, force_blank_string=false
    r  = nil
    # Nokogiri's 'at' method is unreliable.  If the name of the element you're looking for is repeated within the
    # doc structure, it can grab the wrong one and return its value.  For example...
    # <a><c><b>This text could be returned</b></c><b>Even though you're looking for this text</b></a>
    # ...if you were trying to get the value of the 'b' element from 'a'.
    # Thankfully, 'xpath' seems to behave intuitively.
    r = parent.xpath(element_name).first&.text if parent
    r = '' if r.nil? && force_blank_string
    r
  end

  # Gets the text from the first element matching the provided xpath.  Returns nil unless force_blank_string
  # is true, in which case an empty string is returned.
  def first_text xml, xpath, force_blank_string=false
    txt = xml.xpath(xpath).first&.text
    (txt.nil? && force_blank_string) ? "" : txt
  end

  # Grabs all unique values from the XML based on a provided xpath.  Blank values are not included in the returned
  # array unless the method is specifically instructed to include them ('skip_blank_values' value of false).
  # Uniqueness check here is case sensitive: "A" and "a" would be viewed as different values.  Although the method
  # returns an array by default, that array can be converted to CSV instead with an 'as_csv' value of true, as a
  # minor convenience.
  def unique_values xml, xpath, skip_blank_values:true, as_csv:false, csv_separator:","
    s = Set.new
    xml.xpath(xpath).each { |el| s << el.text if el.text.present? || !skip_blank_values }
    arr = s.to_a
    as_csv ? arr.join(csv_separator).strip : arr
  end

  def total_value xml, xpath, total_type: :to_d
    total = BigDecimal.new(0)
    xml.xpath(xpath).each do |el|
      # to_s in here ensures we don't have a nil value, which doesn't work with to_d.
      total += el.text.to_s.try(total_type)
    end
    total.try(total_type)
  end

end; end; end
