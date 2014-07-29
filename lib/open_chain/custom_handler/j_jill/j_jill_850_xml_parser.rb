require 'open_chain/custom_handler/xml_helper'
require 'open_chain/custom_handler/j_jill/j_jill_support'
require 'open_chain/custom_handler/j_jill/j_jill_custom_definition_support'

module OpenChain; module CustomHandler; module JJill; class JJill850XmlParser
  include OpenChain::CustomHandler::XmlHelper
  include OpenChain::CustomHandler::JJill::JJillSupport
  include OpenChain::CustomHandler::JJill::JJillCustomDefinitionSupport  
  extend OpenChain::IntegrationClientParser

  SHIP_MODES ||= {'A'=>'Air','B'=>'Ocean'}
  def self.integration_folder
    ["/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_jjill_850"]
  end

  def self.parse data, opts={}
    parse_dom REXML::Document.new(data)
  end

  def self.parse_dom dom
    self.new.parse_dom dom
  end

  def initialize
    @jill = Company.find_by_system_code UID_PREFIX
    @user = User.find_by_username('integration')
    @cdefs = self.class.prep_custom_definitions [:vendor_style]
    raise "Company with system code #{UID_PREFIX} not found." unless @jill
  end

  def parse_dom dom
    ActiveRecord::Base.transaction do
      r = dom.root
      extract_date = parse_extract_date r
      r.each_element('TS_850') {|el| parse_order el, extract_date}
    end
  end

  private 
  def parse_order order_root, extract_date
    cust_ord = REXML::XPath.first(order_root,'BEG/BEG03').text
    ord_num = "#{UID_PREFIX}-#{cust_ord}"
    ord = Order.find_by_importer_id_and_order_number @jill.id, ord_num
    
    #skip orders already on shipments    
    return if ord && ord.piece_sets.where("shipment_line_id is not null").count > 0

    ord = Order.new(importer_id:@jill.id,order_number:ord_num) unless ord
    return if ord.last_exported_from_source && ord.last_exported_from_source > extract_date
    ord.last_exported_from_source = extract_date
    ord.last_revised_date = extract_date
    ord.customer_order_number = cust_ord
    refs = parse_refs order_root
    ord.vendor = find_or_create_vendor refs['VN']
    ord.order_date = parse_date_string(REXML::XPath.first(order_root,'BEG/BEG05').text)
    ord.mode = ship_mode(REXML::XPath.first(order_root,'TD5/TD504').text)

    parse_header_dtm(order_root,ord)
    
    ord.order_lines.destroy_all
    parse_lines ord, order_root

    agents = ord.available_agents
    ord.agent = agents.first if agents.size == 1
    ord.save!
    EntitySnapshot.create_from_entity ord, @user
  end

  private
  def parse_lines order, order_root
    line_number = 1
    REXML::XPath.each(order_root,'GROUP_11') do |group_el|
      po1_el = REXML::XPath.first(group_el,'PO1')
      ol = order.order_lines.build
      ol.line_number = line_number
      line_number += 1
      ol.quantity = et po1_el, 'PO102'
      ol.price_per_unit = et po1_el, 'PO104'
      ol.sku = et po1_el, 'PO109'
      ol.hts = et(po1_el,'PO115',true).gsub(/\./,'')
      ol.product = parse_product group_el
    end
  end
  def parse_product group_11
    po1_el = REXML::XPath.first(group_11,'PO1')
    prod_uid = "#{UID_PREFIX}-#{et po1_el, 'PO107'}"
    p = Product.where(importer_id:@jill.id,unique_identifier:prod_uid).first_or_create!(name:REXML::XPath.first(group_11,'LIN/LIN03').text)
    cv = p.get_custom_value(@cdefs[:vendor_style])
    vendor_style = et(po1_el,'PO111')
    if cv.value != vendor_style
      cv.value = vendor_style
      cv.save!
    end
    p
  end
  def find_or_create_vendor vendor_ref
    return nil if vendor_ref.nil?
    v = Company.find_by_system_code "#{UID_PREFIX}-#{vendor_ref[0]}"
    if v.nil?
      v = Company.create!(system_code:"#{UID_PREFIX}-#{vendor_ref[0]}",name:vendor_ref[1],vendor:true)
      @jill.linked_companies << v
    end
    v
  end
  def parse_refs parent
    r = {}
    parent.each_element('REF') do |ref_el|
      qualifier = et(ref_el,'REF01')
      v1 = et(ref_el,'REF02')
      v2 = et(ref_el,'REF03')
      r[qualifier] = [v1,v2]
    end
    r
  end

  def parse_extract_date root
    date = REXML::XPath.first(root,'GS/GS04').text
    time = REXML::XPath.first(root,'GS/GS05').text
    Time.gm(date[0,4],date[4,2],date[6,2],time[0,2],time[2,2])
  end

  def parse_header_dtm order_root, order
    REXML::XPath.each(order_root,'DTM') do |dtm|
      code = et(dtm,'DTM01')
      val = parse_date_string(et(dtm,'DTM02'))
      case code
      when '001'
        order.first_expected_delivery_date = val
      when '002'
        order.ship_window_end = val
      when '037'
        order.ship_window_start = val
      end
    end
  end

  def ship_mode str
    return nil if str.blank?
    v = SHIP_MODES[str]
    v = 'Other' if v.blank?
    v
  end

  #get child element date
  def parse_date_string str
    Date.new(str[0,4].to_i,str[4,2].to_i,str[6,2].to_i)
  end
end; end; end; end