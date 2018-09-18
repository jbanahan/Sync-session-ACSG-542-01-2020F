require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/generic/lacey_simplified_order_xml_parser'

module OpenChain; module CustomHandler; module Baillie; class BaillieOrderXmlParser
  extend OpenChain::IntegrationClientParser

  def self.parse_file dom, log, opts={}
    OpenChain::CustomHandler::Generic::LaceySimplifiedOrderXmlParser.parse_file(dom, log, opts)
  end

  def self.integration_folder
    ['baillie/_po_xml', '/home/ubuntu/ftproot/chainroot/baillie/_po_xml']
  end
end; end; end; end
