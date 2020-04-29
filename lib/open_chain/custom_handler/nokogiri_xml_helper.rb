require 'nokogiri'

module OpenChain; module CustomHandler; module NokogiriXmlHelper
  extend ActiveSupport::Concern

  # Build an XML document object from a String or IO object
  def xml_document xml_data, remove_namespaces: true
    self.class.xml_document(xml_data, remove_namespaces: remove_namespaces)
  end

  def est_time_str t
    ActiveSupport::TimeZone["Eastern Time (US & Canada)"].at(t.to_i).strftime("%Y-%m-%d %H:%M %Z")
  end

  # get element text
  # if force_blank_string then send "" instead of null
  def et parent, element_name, force_blank_string=false
    r  = nil
    # Nokogiri's 'at' method is unreliable.  If the name of the element you're looking for is repeated within the
    # doc structure, it can grab the wrong one and return its value.  For example...
    # <a><c><b>This text could be returned</b></c><b>Even though you're looking for this text</b></a>
    # ...if you were trying to get the value of the 'b' element from 'a'.
    # Thankfully, 'xpath' seems to behave intuitively.
    r = xpath(parent, element_name).first&.text if parent
    r = '' if r.nil? && force_blank_string
    r
  end

  # Gets the text from the first element matching the provided xpath.  Returns nil unless force_blank_string
  # is true, in which case an empty string is returned.
  def first_text xml, xpath_expression, force_blank_string=false
    txt = xpath(xml, xpath_expression).first&.text
    (txt.nil? && force_blank_string) ? "" : txt
  end

  # Yield or return each result that is returned from the given xpath expression
  def xpath element, xpath_expression, namespace_bindings: nil, variable_bindings: nil
    if block_given?
      element.xpath(xpath_expression, namespace_bindings, variable_bindings).each(&Proc.new)
      return nil
    else
      return element.xpath(xpath_expression, namespace_bindings, variable_bindings).to_a
    end
  end

  def first_xpath element, xpath_expression, namespace_bindings: nil, variable_bindings: nil
    xpath(element, xpath_expression, namespace_bindings: namespace_bindings, variable_bindings: variable_bindings).first
  end

  # Grabs all unique values from the XML based on a provided xpath.  Blank values are not included in the returned
  # array unless the method is specifically instructed to include them ('skip_blank_values' value of false).
  # Uniqueness check here is case sensitive: "A" and "a" would be viewed as different values.  Although the method
  # returns an array by default, that array can be converted to CSV instead with an 'as_csv' value of true, as a
  # minor convenience.
  def unique_values xml, xpath_expression, skip_blank_values:true, as_csv:false, csv_separator:","
    s = Set.new
    xpath(xml, xpath_expression).each { |el| s << el.text if el.text.present? || !skip_blank_values }
    arr = s.to_a
    as_csv ? arr.join(csv_separator).strip : arr
  end

  def total_value xml, xpath_expression, total_type: :to_d
    total = BigDecimal.new(0)
    xpath(xml, xpath_expression) do |el|
      # to_s in here ensures we don't have a nil value, which doesn't work with to_d.
      total += el.text.to_s.try(total_type)
    end
    total.try(total_type)
  end

  module ClassMethods
    # Build an XML document object from a String or IO object
    def xml_document xml_data, remove_namespaces: true
      doc = Nokogiri::XML(xml_data)
      # By default, we eliminate namespaces from the document.  In general, most documents we receive utilize a single namespace
      # and that namespace really provides no actual purpose for the document.  Removing the namespace makes all the xpath expressions
      # utilized on a document more streamlined and easier to read.
      doc.remove_namespaces! if remove_namespaces
      doc
    end
  end

end; end; end
