require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/xml_helper'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
require 'open_chain/workflow_processor'
module OpenChain; module CustomHandler; module LumberLiquidators; class LumberSapVendorXmlParser
  include OpenChain::CustomHandler::XmlHelper
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport  
  extend OpenChain::IntegrationClientParser

  def self.parse data, opts={}
    parse_dom REXML::Document.new(data), opts
  end

  def self.parse_dom dom, opts={}
    self.new(opts).parse_dom dom
  end

  def initialize opts={}
    inner_opts = {workflow_processor:WorkflowProcessor.new}.merge opts
    @cdefs = self.class.prep_custom_definitions [:cmp_sap_company]
    @wfp = inner_opts[:workflow_processor]
    @user = User.integration
  end

  def parse_dom dom
    root = dom.root
    raise "Incorrect root element #{root.name}, expecting 'CREMAS05'." unless root.name == 'CREMAS05'
    base = REXML::XPath.first(root,'//E1LFA1M')
    sap_code = et(base,'LIFNR')
    raise "Missing SAP Number. All vendors must have SAP Number at XPATH //E1LFA1M/LIFNR" if sap_code.blank?
    name = et(base,'NAME1')
    ActiveRecord::Base.transaction do
      c = Company.where(system_code:sap_code).first_or_create!(name:name,vendor:true)
      sap_num_cv = c.get_custom_value(@cdefs[:cmp_sap_company])
      
      attributes_to_update = {}      
      attributes_to_update[:vendor] = true unless c.vendor?
      attributes_to_update[:name] = name unless c.name == name
      c.update_attributes(attributes_to_update) unless attributes_to_update.empty?

      if sap_num_cv.value!=sap_code
        sap_num_cv.value = sap_code
        sap_num_cv.save!
        c.touch
      end

      update_address c, sap_code, base

      @wfp.process! c, @user
    end
  end

  private
  def update_address company, sap_code, el
    add_sys_code = "#{sap_code}-CORP"
    add = company.addresses.where(system_code:add_sys_code).first_or_create!(name:'Corporate')
    country_iso = et(el,'LAND1')
    country = Country.find_by_iso_code country_iso
    raise "Invalid country code #{country_iso}." unless country
    attributes_to_update = {}      
    add_if_change attributes_to_update, add.line_1, et(el,'STRAS'), :line_1
    add_if_change attributes_to_update, add.city, et(el,'ORT01'), :city
    add_if_change attributes_to_update, add.state, et(el,'REGIO'), :state
    add_if_change attributes_to_update, add.postal_code, et(el,'PSTLZ'), :postal_code
    add_if_change attributes_to_update, add.country_id, country.id, :country_id
    add.update_attributes(attributes_to_update) unless attributes_to_update.empty?
  end

  def add_if_change hash, old_val, new_val, sym
    hash[sym] = new_val unless old_val == new_val
  end
end; end; end; end