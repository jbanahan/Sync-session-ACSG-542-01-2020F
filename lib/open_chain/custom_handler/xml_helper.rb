require 'nokogiri'
require 'rexml/document'

module OpenChain; module CustomHandler; module XmlHelper
  extend ActiveSupport::Concern

  def est_time_str t
    ActiveSupport::TimeZone["Eastern Time (US & Canada)"].at(t.to_i).strftime("%Y-%m-%d %H:%M %Z")
  end

  # get element text
  # if force_blank_string then send "" instead of null
  def et parent, element_name, force_blank_string = false
    r = nil
    r = parent.text(element_name) if parent
    r = '' if r.nil? && force_blank_string
    r
  end

  # Gets the text from the first element matching the provided xpath.  Returns nil unless force_blank_string
  # is true, in which case an empty string is returned.
  def first_text xml, xpath, force_blank_string = false
    txt = REXML::XPath.first(xml, xpath).try(:text)
    (txt.nil? && force_blank_string) ? "" : txt
  end

  # Grabs all unique values from the XML based on a provided xpath.  Blank values are not included in the returned
  # array unless the method is specifically instructed to include them ('skip_blank_values' value of false).
  # Uniqueness check here is case sensitive: "A" and "a" would be viewed as different values.  Although the method
  # returns an array by default, that array can be converted to CSV instead with an 'as_csv' value of true, as a
  # minor convenience.
  def unique_values xml, xpath, skip_blank_values: true, as_csv: false, csv_separator: ","
    s = Set.new
    REXML::XPath.each(xml, xpath) { |el| s << el.text if el.text.present? || !skip_blank_values }
    arr = s.to_a
    as_csv ? arr.join(csv_separator).strip : arr
  end

  def total_value xml, xpath, total_type: :to_d
    total = BigDecimal(0)
    REXML::XPath.each(xml, xpath) do |el|
      # to_s in here ensures we don't have a nil value, which doesn't work with to_d.
      total += el.text.to_s.try(total_type)
    end
    total.try(total_type)
  end

  def xml_document xml_data
    self.class.xml_document xml_data
  end

  module ClassMethods

    def included(_base)
      private_class_method :raise_exception
      private_class_method :rexml_duplicate_root_element_error?
      private_class_method :parse_duplicate_root_element_xml
    end

    # Build an XML document object from a String or IO object
    def xml_document xml_data
      xml = nil
      xml = REXML::Document.new(xml_data)
    rescue REXML::ParseException => e
        if rexml_duplicate_root_element_error?(e)
          xml = parse_duplicate_root_element_xml(xml_data)
          # If nil is returned, it means we could work around the duplicate document issue, just raise the original error if this happens
          raise_exception(e) if xml.nil?
        else
          raise_exception(e)
        end
        xml
    end

    # private

    def raise_exception e
      if self.respond_to? :inbound_file
        inbound_file.reject_and_raise(e.message)
      else
        raise e
      end
    end

    def rexml_duplicate_root_element_error? e
      e.message.to_s.downcase.include? "attempted adding second root element to document"
    end

    def parse_duplicate_root_element_xml xml_data
      # It just so happens that Nokogiri transparently handles duplicate root elements, so I'm going to just build the document in nokogiri, and then write
      # the data to an IO object and parse that.
      xml = Nokogiri::XML xml_data
      # Use a compact output format just to make the data smaller that REXML needs to deal with
      REXML::Document.new(xml.to_xml(indent: 0, save_with: Nokogiri::XML::Node::SaveOptions::AS_XML))
    rescue StandardError
      # If anything blows up here, just return nil...it means we couldn't handle trying to fix the XML and will signal
      # that we should just raise the original exception
      nil
    end
  end

end; end; end
