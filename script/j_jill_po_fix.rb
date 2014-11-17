require 'open_chain/s3'
require 'open_chain/custom_handler/xml_helper'
require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/j_jill/j_jill_support'
require 'open_chain/custom_handler/j_jill/j_jill_custom_definition_support'

class JJillPOFix
  include OpenChain::CustomHandler::XmlHelper
  include OpenChain::CustomHandler::JJill::JJillSupport
  include OpenChain::CustomHandler::JJill::JJillCustomDefinitionSupport  
  extend OpenChain::IntegrationClientParser

  SHIP_VIA_CODES ||= {'2'=>'Air Collect','3'=>'Boat','4'=>'Air Prepaid','5'=>'Air Sea Diff'}

  def self.update_all_2014_11_17
    # cdefs = prep_custom_definitions([:vendor_style])
    x = self.new
    jill = Company.find_by_system_code UID_PREFIX
    jill.importer_orders.each do |ord|
      # x.update_product_category ord, cdefs
      x.update_fingerprint ord
    end
  end

  def update_product_category order, cdefs = self.class.prep_custom_definitions([:vendor_style])
    products = Set.new
    order.order_lines.each {|ol| products << ol.product}
    vs = products.collect {|p| p.get_custom_value(cdefs[:vendor_style]).value}.uniq
    vs = [] if vs.blank?
    order.update_attributes(product_category:get_product_category_from_vendor_styles(vs))
  end

  def update_fingerprint ord
    fingerprint = generate_order_fingerprint ord
    DataCrossReference.create_jjill_order_fingerprint!(ord,fingerprint)
  end

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
    @jill = Company.find_by_system_code UID_PREFIX
    @user = User.integration
    @cdefs = self.class.prep_custom_definitions self.class::CUSTOM_DEFINITION_INSTRUCTIONS.keys
    raise "Company with system code #{UID_PREFIX} not found." unless @jill
  end

  def parse_dom dom
    ActiveRecord::Base.transaction do
      r = dom.root
      r.each_element('//TRANSACTION_SET') {|el| parse_order el}
    end
  end

  def parse_order order_root
    ord = get_order order_root
    if ord.nil?
      puts "SKIPPING ORDER"
      return
    end
    ord.update_custom_value!(@cdefs[:ship_type],SHIP_VIA_CODES[REXML::XPath.first(order_root,'TD5/TD501').text])
    ord.update_custom_value!(@cdefs[:entry_port_name],REXML::XPath.first(order_root,'TD5/TD508').text)
    ord.season = REXML::XPath.first(order_root,"REF[REF01 = 'ZZ']/REF02").text
    ord.terms_of_sale = REXML::XPath.first(order_root,'ITD/ITD12').text
    set_ship_to ord, order_root
    ord.save!

    REXML::XPath.each(order_root,'GROUP_11') do |group_el|
      po1_el = REXML::XPath.first(group_el,'PO1')
      sku = et po1_el, 'PO109'
      ol = ord.order_lines.find_by_sku sku
      next unless ol
      ol.update_custom_value! @cdefs[:color], et(po1_el, 'PO113')
      ol.update_custom_value! @cdefs[:size], et(po1_el, 'PO119')

      p = ol.product
      imp_cv = p.get_custom_value(@cdefs[:importer_style])
      importer_style = et(po1_el,'PO107')
      if imp_cv.value != importer_style
        imp_cv.value = importer_style
        imp_cv.save!
      end
    end
  end

  def set_ship_to ord, order_root
    st = Address.new(company_id:@jill.id)
    ship_to_root = REXML::XPath.first(order_root,"GROUP_5[N1/N101='ST']")
    return unless ship_to_root
    n1 = REXML::XPath.first(ship_to_root,'N1')
    n4 = REXML::XPath.first(ship_to_root,'N4')
    st.name = et n1, 'N102'
    st.system_code = et n1, 'N104'
    st.line_1 = 'RECEIVING'
    st.line_2 = et(REXML::XPath.first(ship_to_root,'N3'),'N301')
    st.city = et n4, 'N401'
    st.state = et n4, 'N402'
    st.postal_code = et n4, 'N403'
    st.country = (et(n4,'N404')=='USA' ? Country.find_by_iso_code('US') : nil)

    hash_key = Address.make_hash_key st
    found_address = Address.find_by_address_hash_and_company_id hash_key, @jill.id
    if found_address
      ord.ship_to = found_address
    else
      st.save!
      ord.ship_to = st
    end
    nil #return
  end

  def get_order order_root
    cust_ord = REXML::XPath.first(order_root,'BEG/BEG03').text
    ord_num = "#{UID_PREFIX}-#{cust_ord}"
    ord = Order.find_by_importer_id_and_order_number @jill.id, ord_num
  end
end