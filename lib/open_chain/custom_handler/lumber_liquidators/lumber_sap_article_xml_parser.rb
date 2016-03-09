require 'rexml/document'
require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/xml_helper'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberSapArticleXmlParser
  include OpenChain::CustomHandler::XmlHelper
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport  
  extend OpenChain::IntegrationClientParser

  def self.parse data, opts={}
    parse_dom REXML::Document.new(data), opts
  end

  def self.parse_dom dom, opts={}
    self.new.parse_dom dom
  end

  def self.integration_folder
    "/home/ubuntu/ftproot/chainroot/ll/_sap_article_xml"
  end

  def initialize
    @user = User.integration
    @cdefs = self.class.prep_custom_definitions [:prod_sap_extract, :prod_old_article]
  end

  def parse_dom dom
    root = dom.root
    raise "Incorrect root element #{root.name}, expecting '_-LUMBERL_-VFI_ARTMAS01'." unless root.name == '_-LUMBERL_-VFI_ARTMAS01'
    prod_el = REXML::XPath.first(root,'//IDOC/E1BPE1MAKTRT')
    uid = et(prod_el,'MATERIAL')
    raise "XML must have Material number at /_-LUMBERL_-VFI_ARTMAS01/IDOC/E1BPE1MAKTRT/MATERIAL" if uid.blank?
    name = et(prod_el,'MATL_DESC')

    envelope = REXML::XPath.first(root,'//IDOC/EDI_DC40')
    ext_time = extract_time(envelope)

    p = nil
    Lock.acquire("Product-#{uid}") do
      p = Product.where(unique_identifier: uid).first_or_create!
    end

    Lock.with_lock_retry(p) do
      previous_extract_time = p.custom_value(@cdefs[:prod_sap_extract])
      if previous_extract_time && previous_extract_time.to_i > ext_time.to_i
        return # don't parse since this is older than the previous extract
      end

      p.importer = Company.where(master: true).first
      p.name = name
      p.find_and_set_custom_value(@cdefs[:prod_sap_extract], ext_time)
      p.find_and_set_custom_value(@cdefs[:prod_old_article], et(REXML::XPath.first(root,'//IDOC/E1BPE1MARART'),'OLD_MAT_NO'))
      hts_parent = REXML::XPath.first(root, '//IDOC/E1BPE1MAW1RT[@SEGMENT="1"]')
      hts = hts_parent.nil? ? "" : et(hts_parent, "COMM_CODE")
      set_us_hts p, hts

      p.save!
      p.create_snapshot(@user)
    end
  end

  private
    def extract_time envelope_element
      date_part = et(envelope_element,'CREDAT')
      time_part = et(envelope_element,'CRETIM')

      # match ActiveSupport::TimeZone.parse
      formatted_date = "#{date_part[0,4]}-#{date_part[4,2]}-#{date_part[6,2]} #{time_part[0,2]}:#{time_part[2,2]}:#{time_part[4,2]}"

      ActiveSupport::TimeZone['Eastern Time (US & Canada)'].parse(formatted_date)
    end

    def set_us_hts product, hts
      usa = us
      classification = product.classifications.find {|c| c.country_id = usa.id }

      # Don't bother building a classification if HTS is blank and the classification hasn't been created yet
      return if hts.blank? && classification.nil?

      if classification.nil?
        classification = product.classifications.build country_id: usa.id
      end

      tariff_record = classification.tariff_records.to_a.sort_by {|t| t.line_number }.first

      if tariff_record.nil?
        tariff_record = classification.tariff_records.build
      end

      tariff_record.hts_1 = hts
    end

    def us
      @us ||= Country.where(iso_code: "US").first
      raise "No Country found for iso code 'US'." unless @us
      @us
    end
end; end; end; end;