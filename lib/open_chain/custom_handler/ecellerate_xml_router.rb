require 'rexml/document'
require 'rexml/xpath'
require 'open_chain/custom_handler/xml_helper'
require 'open_chain/custom_handler/j_jill/j_jill_ecellerate_xml_parser'

module OpenChain; module CustomHandler; class EcellerateXmlRouter
  extend OpenChain::CustomHandler::XmlHelper
  extend OpenChain::IntegrationClientParser

  def self.integration_folder
    ["www-vfitrack-net/_ecellerate_shipment", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_ecellerate_shipment"]
  end

  def self.parse_file data, log, opts={}
    parse_dom REXML::Document.new(data), log
  end

  def self.parse_dom dom, log
    imp = nil
    REXML::XPath.each(dom.root,'//Parties/Party') do |p|
      if et(p,'PartyType') == 'Importer'
        imp = et(p,'PartyCode') 
        break
      end
    end
    case imp
    when 'JILSO'
      OpenChain::CustomHandler::JJill::JJillEcellerateXmlParser.parse_dom dom, log
    end
  end
end; end; end