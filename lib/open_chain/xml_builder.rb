module OpenChain
  module XmlBuilder

    def build_xml_document root_element_name
      doc = REXML::Document.new("<?xml version=\"1.0\" encoding=\"UTF-8\"?><#{root_element_name}></#{root_element_name}>")
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
  end
end