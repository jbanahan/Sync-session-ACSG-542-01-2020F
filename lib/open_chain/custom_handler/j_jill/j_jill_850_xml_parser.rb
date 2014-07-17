require 'rexml/document'
require 'rexml/xpath'
require 'open_chain/custom_handler/xml_helper'

module OpenChain; module CustomHandler; module JJill; class JJill850XmlParser
  include OpenChain::CustomHandler::XmlHelper
  extend OpenChain::IntegrationClientParser

  def self.integration_folder
    ["/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_jjill_850"]
  end

  def self.parse data, user, opts={}
    parse_dom REXML::Document.new(data), user
  end

  def self.parse_dom dom, user
    self.new.parse_dom dom, user
  end

  def initialize
    @jill = Company.find_by_system_code 'JILL'
    raise "Company with system code JILL not found." unless @jill
  end

  def parse_dom dom, user
    ActiveRecord::Base.transaction do
      r = dom.root
      extract_date = parse_extract_date r
      r.each_element('TS_850') {|el| parse_order el, extract_date, user}
    end
  end

  private 
  def parse_order order_root, extract_date, user
    cust_ord = REXML::XPath.first(order_root,'BEG/BEG03').text
    ord_num = "JILL-#{cust_ord}"
    ord = Order.find_by_importer_id_and_order_number @jill.id, ord_num
    
    #skip orders already on shipments    
    return if ord && ord.piece_sets.where("shipment_line_id is not null").count > 0

    ord = Order.new(importer_id:@jill.id,order_number:ord_num) unless ord
    return if ord.last_exported_from_source && ord.last_exported_from_source > extract_date
    ord.last_exported_from_source = extract_date
    ord.customer_order_number = cust_ord
    refs = parse_refs order_root
    ord.vendor = find_or_create_vendor refs['VN']
    ord.order_date = parse_date_string(REXML::XPath.first(order_root,'BEG/BEG05').text)
    
    ord.order_lines.destroy_all
    parse_lines ord, order_root

    ord.save!
    EntitySnapshot.create_from_entity ord, user
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
    prod_uid = "JILL-#{et po1_el, 'PO107'}"
    Product.where(importer_id:@jill.id,unique_identifier:prod_uid).first_or_create!(name:REXML::XPath.first(group_11,'LIN/LIN03').text)
  end
  def find_or_create_vendor vendor_ref
    return nil if vendor_ref.nil?
    v = Company.find_by_system_code "JILL-#{vendor_ref[0]}"
    if v.nil?
      v = Company.create!(system_code:"JILL-#{vendor_ref[0]}",name:vendor_ref[1])
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

  #get child element date
  def parse_date_string str
    Date.new(str[0,4].to_i,str[4,2].to_i,str[6,2].to_i)
  end
end; end; end; end