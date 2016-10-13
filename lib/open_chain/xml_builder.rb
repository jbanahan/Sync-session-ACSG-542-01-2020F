require "rexml/document"

module OpenChain; module XmlBuilder
  extend ActiveSupport::Concern

  def build_xml_document root_element_name, options = {}
    xml = options[:suppress_xml_declaration] ? "" : "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    xml = "#{xml}<#{root_element_name}></#{root_element_name}>"
    doc = REXML::Document.new(xml)
    [doc, doc.root]
  end

  def write_xml document, io
    REXML::Formatters::Default.new.write document, io
  end

  def add_element parent_element, child_element_name, content = nil, opts={}
    opts = {allow_blank: true}.merge opts
    child = nil
    if opts[:allow_blank] || content
      child = parent_element.add_element(child_element_name)
      if content
        if opts[:cdata]
          child.text = REXML::CData.new content
        else
          child.text = content
        end
      end
    end
    child
  end

  # Adds outer_el_name element to the parent, then adds an inner_el_name child elements below outer_el_name
  # for each value found after splitting values.
  #
  # Unless the values param answers to to_a, splits up the data given in values using the given expression (defaults to splitting on newlines)
  # Output would look like the following given a value of "Value 1\nValue 2"
  # <parent>
  #   <outer_el_name>
  #     <inner_el_name>Value 1</inner_el_name>
  #     <inner_el_name>Value 2</inner_el_name>
  #   </outer_el_name>
  # </parent>
  def add_collection_element parent, outer_el_name, inner_el_name, values, split_expression: /\n\s*/
    el = add_element parent, outer_el_name
    vals = values.respond_to?(:to_a) ? values.to_a : values.to_s.split(split_expression)
    vals.each do |v|
      next if v.blank?
      add_element el, inner_el_name, v
    end
    el
  end

  # Because EDI splits date and time into multiple segments, for ease of translation
  # we'll split them in XML as well when we intend to translate XML docs to EDI.
  # If not translating..just use an iso8601'ized date/time.
  def add_date_elements parent, date, element_prefix: "", date_format: "%Y%m%d", time_format: "%H%M", child_element_name: nil
    return unless date

    if child_element_name
      # See if the child element name exists already under the given parent element, otherwise create it
      entity = parent.get_elements(child_element_name).first
      if entity.nil?
        entity = add_element parent, child_element_name
      end
    else
      entity = parent
    end

    add_element entity, "#{element_prefix}Date", date.strftime(date_format)
    if date.respond_to?(:acts_like_time?) && date.acts_like_time?
      add_element entity, "#{element_prefix}Time", date.strftime(time_format)
    else
      add_element entity, "#{element_prefix}Time", Date.new(0).strftime(time_format)
    end

    entity
  end

  def add_entity_address_info parent, entity_name, name: nil, id: nil, address_1: nil, address_2: nil, city: nil, state: nil, zip: nil, country: nil
    entity = add_element parent, entity_name
    add_element entity, "Name", name
    add_element entity, "Id", id
    add_element entity, "Address1", address_1
    add_element entity, "Address2", address_2
    add_element entity, "City", city
    add_element entity, "State", state
    add_element entity, "Zip", zip
    add_element entity, "Country", country

    entity
  end

end; end
