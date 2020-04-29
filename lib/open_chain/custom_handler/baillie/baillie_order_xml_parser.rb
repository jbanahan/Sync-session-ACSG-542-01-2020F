require 'open_chain/custom_handler/generic/lacey_simplified_order_xml_parser'

module OpenChain; module CustomHandler; module Baillie; class BaillieOrderXmlParser < OpenChain::CustomHandler::Generic::LaceySimplifiedOrderXmlParser

  def self.integration_folder
    ['baillie/_po_xml', '/home/ubuntu/ftproot/chainroot/baillie/_po_xml']
  end

end; end; end; end
