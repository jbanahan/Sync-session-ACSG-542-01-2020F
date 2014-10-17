require 'digest/md5'
require 'open_chain/integration_client_parser'
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
    parse_dom REXML::Document.new(data), opts
  end

  def self.parse_dom dom, opts={}
    self.new(opts).parse_dom dom
  end

  def initialize opts={}
    @inner_opts = {force_header_updates:false}
    @inner_opts = @inner_opts.merge opts
    @jill = Company.find_by_system_code UID_PREFIX
    @user = User.integration
    @cdefs = self.class.prep_custom_definitions [:vendor_style]
    raise "Company with system code #{UID_PREFIX} not found." unless @jill
  end

  def parse_dom dom
    ActiveRecord::Base.transaction do
      r = dom.root
      extract_date = parse_extract_date r
      r.each_element('//TRANSACTION_SET') {|el| parse_order el, extract_date}
    end
  end

  private 
  def parse_order order_root, extract_date
    cancel = REXML::XPath.first(order_root,'BEG/BEG01').text=='03'
    cust_ord = REXML::XPath.first(order_root,'BEG/BEG03').text
    ord_num = "#{UID_PREFIX}-#{cust_ord}"
    ord = Order.find_by_importer_id_and_order_number @jill.id, ord_num
    
    update_lines = true
    update_header = true
    po_assigned_to_shipment = false
    #skip orders already on shipments    
    if ord && ord.piece_sets.where("shipment_line_id is not null").count > 0
      update_header = @inner_opts[:force_header_updates]
      update_lines = false
      po_assigned_to_shipment = true
    end

    ord = Order.new(importer_id:@jill.id,order_number:ord_num) unless ord
    return if ord.last_exported_from_source && ord.last_exported_from_source > extract_date

    if update_header
      update_order_header ord, extract_date, cust_ord, order_root 
      agents = ord.available_agents
      ord.agent = agents.first if agents.size == 1
    end
    
    if update_lines
      ord.order_lines.destroy_all
      parse_lines ord, order_root
    end

    if update_header || update_lines
      ord.save! 
      EntitySnapshot.create_from_entity ord, @user
    end

    if po_assigned_to_shipment
      message = "Order ##{cust_ord} already assigned to a Shipment"
      OpenMailer.send_simple_html("jjill_orders@vandegriftinc.com", "[VFI Track] #{message}", message).deliver!
    elsif cancel && !ord.closed?
      ord.close! @user
    elsif !cancel && ord.closed?
      ord.reopen! @user
    end

    fingerprint = generate_fingerprint ord
    fp = DataCrossReference.find_jjill_order_fingerprint(ord)
    if fingerprint!=fp
      if !po_assigned_to_shipment && ord.approval_status == 'Accepted'
        ord.unaccept! @user
      end
      DataCrossReference.create_jjill_order_fingerprint!(ord,fingerprint)
    end


  end

  private

  def generate_fingerprint ord
    f = ""
    f << ord.customer_order_number.to_s
    f << ord.vendor_id.to_s
    f << ord.mode.to_s
    f << ord.fob_point.to_s
    f << ord.first_expected_delivery_date.to_s
    f << ord.ship_window_start.to_s
    f << ord.ship_window_end.to_s
    ord.order_lines.each do |ol|
      f << ol.quantity.to_s
      f << ol.price_per_unit.to_s
      f << ol.sku.to_s
    end
    Digest::MD5.hexdigest f
  end

  def update_order_header ord, extract_date, cust_ord, order_root
    ord.last_exported_from_source = extract_date
    ord.last_revised_date = extract_date
    ord.customer_order_number = cust_ord
    refs = parse_refs order_root
    ord.vendor = find_or_create_vendor refs['VN']
    ord.factory = find_or_create_factory ord.vendor, order_root
    ord.order_date = parse_date_string(REXML::XPath.first(order_root,'BEG/BEG05').text)
    ord.mode = ship_mode(REXML::XPath.first(order_root,'TD5/TD504').text)
    ord.fob_point = REXML::XPath.first(order_root,'FOB/FOB07').text
    parse_header_dtm(order_root,ord)
  end
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
    prod_uid = "#{UID_PREFIX}-#{et po1_el, 'PO111'}"
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
  def find_or_create_factory vendor, order_root
    factory_el = nil
    REXML::XPath.each(order_root,'GROUP_5') do |g5|
      if REXML::XPath.first(g5,'N1/N101').text == 'SU'
        factory_el = g5
        break
      end
    end
    return unless factory_el
    mid = REXML::XPath.first(factory_el,'N1/N104').text
    return if mid.blank? #can't load factory with blank MID
    sys_code = "#{UID_PREFIX}-#{mid}"
    f = Company.find_by_system_code sys_code
    if f.nil?
      nm = REXML::XPath.first(factory_el,'N1/N102').text
      f = Company.create!(system_code:sys_code,name:nm,factory:true)
    end
    @jill.linked_companies << f if !@jill.linked_companies.include?(f)
    vendor.linked_companies << f if vendor && !vendor.linked_companies.include?(f)
    f
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
    date = REXML::XPath.first(root,'INTERCHANGE/GROUP/GS/GS04').text
    time = REXML::XPath.first(root,'INTERCHANGE/GROUP/GS/GS05').text
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