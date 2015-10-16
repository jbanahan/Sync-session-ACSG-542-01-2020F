require "rexml/document"

module OpenChain; module XmlBuilder
  extend ActiveSupport::Concern

  def build_xml_document root_element_name, options = {}
    xml = options[:suppress_xml_declaration] ? "" : "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    xml = "#{xml}<#{root_element_name}></#{root_element_name}>"
    doc = REXML::Document.new(xml)
    [doc, doc.root]
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

  def add_collection_element parent, outer_el_name, inner_el_name, values
    el = add_element parent, outer_el_name
    vals = values.respond_to?(:to_a) ? values.to_a : values.to_s.split(/\n\s*/)
    vals.each do |v|
      next if v.blank?
      add_element el, inner_el_name, v
    end
    el
  end
end; end