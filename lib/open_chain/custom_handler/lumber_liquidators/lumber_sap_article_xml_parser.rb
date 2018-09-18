require 'rexml/document'
require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/xml_helper'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberSapArticleXmlParser
  include OpenChain::CustomHandler::XmlHelper
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  extend OpenChain::IntegrationClientParser

  def self.parse_file data, log, opts={}
    parse_dom REXML::Document.new(data), log, opts
  end

  def self.parse_dom dom, log, opts={}
    self.new.parse_dom(dom, log, opts)
  end

  def self.integration_folder
    ["ll/_sap_article_xml", "/home/ubuntu/ftproot/chainroot/ll/_sap_article_xml"]
  end

  def initialize
    @user = User.integration
    @cdefs = self.class.prep_custom_definitions [:ordln_old_art_number, :ordln_part_name, :prod_sap_extract, :prod_old_article, :prod_merch_cat, :prod_merch_cat_desc, :prod_overall_thickness]
  end

  def parse_dom dom, log, opts={}
    root = dom.root
    log.error_and_raise "Incorrect root element #{root.name}, expecting '_-LUMBERL_-VFI_ARTMAS01'." unless root.name == '_-LUMBERL_-VFI_ARTMAS01'
    prod_el = REXML::XPath.first(root,'//IDOC/E1BPE1MAKTRT')
    uid = et(prod_el,'MATERIAL')
    log.reject_and_raise "XML must have Material number at /_-LUMBERL_-VFI_ARTMAS01/IDOC/E1BPE1MAKTRT/MATERIAL" if uid.blank?
    name = et(prod_el,'MATL_DESC')

    envelope = REXML::XPath.first(root,'//IDOC/EDI_DC40')
    ext_time = extract_time(envelope)

    importer = Company.where(master: true).first
    log.company = importer

    p = nil
    Lock.acquire("Product-#{uid}") do
      p = Product.where(unique_identifier: uid).first_or_create!
    end

    Lock.with_lock_retry(p) do
      log.add_identifier InboundFileIdentifier::TYPE_ARTICLE_NUMBER, uid, module_type:Product.to_s, module_id:p.id

      previous_extract_time = p.custom_value(@cdefs[:prod_sap_extract])
      if previous_extract_time && previous_extract_time.to_i > ext_time.to_i
        log.add_info_message "Product not updated: file contained outdated info."
        return # don't parse since this is older than the previous extract
      end

      is_new = p.get_custom_value(@cdefs[:prod_sap_extract]).value.blank?

      p.importer = importer
      p.name = name
      p.last_file_bucket = opts[:bucket]
      p.last_file_path = opts[:key]
      p.find_and_set_custom_value(@cdefs[:prod_sap_extract], ext_time)
      p.find_and_set_custom_value(@cdefs[:prod_old_article], et(REXML::XPath.first(root,'//IDOC/E1BPE1MARART'),'OLD_MAT_NO'))
      p.find_and_set_custom_value(@cdefs[:prod_merch_cat], et(REXML::XPath.first(root,'//IDOC/E1BPE1MATHEAD'),'MATL_GROUP'))
      p.find_and_set_custom_value(@cdefs[:prod_merch_cat_desc], et(REXML::XPath.first(root,'//IDOC/_-LUMBERL_-Z1JDA_ARTMAS_EXT'),'MERCH_CAT_DESC'))
      p.find_and_set_custom_value(@cdefs[:prod_overall_thickness], et(REXML::XPath.first(root,'//IDOC/_-LUMBERL_-Z1JDA_ARTMAS_CHAR[ATNAM="OVERALL_THICKNESS"]'),'ATWTB'))

      if is_new
        orders_updated = {}
        p.order_lines.find_each do |order_line|
          line_changed = false
          unless order_line.custom_value(@cdefs[:ordln_old_art_number]).present?
            order_line.find_and_set_custom_value(@cdefs[:ordln_old_art_number], p.get_custom_value(@cdefs[:prod_old_article]).value).save!
            line_changed = true
          end
          unless order_line.custom_value(@cdefs[:ordln_part_name]).present?
            order_line.find_and_set_custom_value(@cdefs[:ordln_part_name], p.name).save!
            line_changed = true
          end
          order_line.order.create_snapshot(@user, nil, "System Job: SAP Article XML Parser") if line_changed
          if line_changed && !orders_updated.key?(order_line.order_id)
            orders_updated[order_line.order_id] = order_line.order.order_number
          end
        end
        orders_updated.each {|order_id, po_number| log.add_identifier InboundFileIdentifier::TYPE_PO_NUMBER, po_number, module_type:Order.to_s, module_id:order_id }
      end

      p.save!
      p.create_snapshot(@user, nil, "System Job: SAP Article XML Parser")
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

end; end; end; end;
