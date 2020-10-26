require 'open_chain/custom_handler/nokogiri_xml_helper'

module OpenChain; module CustomHandler; module Vandegrift; module CargowiseXmlSupport
  extend ActiveSupport::Concern
  include OpenChain::CustomHandler::NokogiriXmlHelper

  def unwrap_document_root document
    # Root varies depending on how the XML is exported.  Dump UniversalInterchange/Body from the structure if it's included.
    if document.root.name == 'UniversalInterchange'
      document = first_xpath(document, "UniversalInterchange/Body")
    end

    document
  end

end; end; end; end