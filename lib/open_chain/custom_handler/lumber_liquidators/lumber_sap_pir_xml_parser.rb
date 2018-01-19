require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/xml_helper'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberSapPirXmlParser
  include OpenChain::CustomHandler::XmlHelper
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  extend OpenChain::IntegrationClientParser

  def self.parse data, opts={}
    parse_dom REXML::Document.new(data), opts
  end

  def self.parse_dom dom, opts={}
    self.new(opts).parse_dom dom
  end

  def self.integration_folder
    ["ll/_sap_pir_xml", "/home/ubuntu/ftproot/chainroot/ll/_sap_pir_xml"]
  end

  def initialize opts={}
    @user = User.integration
    @cdefs = self.class.prep_custom_definitions [:cmp_sap_company]
    @opts = opts
  end

  def parse_dom dom
    root = dom.root
    raise "Incorrect root element #{root.name}, expecting 'INFREC01'." unless root.name == 'INFREC01'

    idoc_number = REXML::XPath.first(root,'IDOC/EDI_DC40').text('DOCNUM')

    base = REXML::XPath.first(root,'IDOC/E1EINAM')

    vendor_sap_number = et(base,'LIFNR')
    raise "IDOC #{idoc_number} failed, no LIFNR value." if vendor_sap_number.blank?
    sc = SearchCriterion.new(model_field_uid:@cdefs[:cmp_sap_company].model_field_uid,operator:'eq',value:vendor_sap_number)
    vendor = sc.apply(Company).first
    return unless vendor

    product_uid = et(base,'MATNR')
    raise "IDOC #{idoc_number} failed, no MATR value." if product_uid.blank?
    p = Product.where(unique_identifier:product_uid).first_or_create!

    pva = ProductVendorAssignment.where(product_id:p.id,vendor_id:vendor.id).first
    if pva.nil?
      pva = ProductVendorAssignment.create!(product_id:p.id,vendor_id:vendor.id)
      pva.create_snapshot(User.integration, nil, "System Job: SAP PIR XML Parser") if pva.entity_snapshots.empty?
    end
    return pva #return value not required but helpful for debugging
  end

end; end; end; end
