require 'rexml/document'
require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/xml_helper'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberSapOrderXmlParser
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
    "/home/ubuntu/ftproot/chainroot/ll/_sap_po_xml"
  end

  def initialize opts={}
    @user = User.integration
    @imp = Company.find_by_master(true)
    @cdefs = self.class.prep_custom_definitions [:ord_sap_extract]
  end

  def parse_dom dom
    @first_expected_delivery_date = nil
    root = dom.root
    raise "Incorrect root element #{root.name}, expecting 'ORDERS05'." unless root.name == 'ORDERS05'

    base = REXML::XPath.first(root,'IDOC')

    # order header info
    order_header = REXML::XPath.first(base,'E1EDK01')
    order_type = et(order_header,'BSART')
    order_number = et(order_header,'BELNR')
    vendor_system_code = et(order_header,'RECIPNT_NO')

    # envelope info
    envelope = REXML::XPath.first(root,'//IDOC/EDI_DC40')
    ext_time = extract_time(envelope)

    ActiveRecord::Base.transaction do
      o = Order.find_by_order_number(order_number)
      if o
        previous_extract_time = o.get_custom_value(@cdefs[:ord_sap_extract]).value
        if previous_extract_time && previous_extract_time.to_i > ext_time.to_i
          return # don't parse since this is older than the previous extract
        end
      else
        o = Order.new(order_number:order_number,importer:@imp)
      end

      # creating the vendor shell record if needed and putting the SAP code as the name since we don't have anything better to use
      vend = Company.where(system_code:vendor_system_code).first_or_create!(vendor:true,name:vendor_system_code)
      o.vendor = vend
      o.order_date = order_date(base)

      REXML::XPath.each(base,'./E1EDP01') {|el| process_line o, el}

      validate_line_totals(o,base)

      o.save!
      o.update_custom_value!(@cdefs[:ord_sap_extract],ext_time)
      o.create_snapshot @user
    end
  end

  def validate_line_totals order, base_el
    expected_el = REXML::XPath.first(base_el,'E1EDS01/SUMME')
    return true if expected_el.nil?
    expected = BigDecimal(expected_el.text)
    actual = order.order_lines.inject(BigDecimal('0.00')) {|mem,ln| mem + BigDecimal(ln.quantity * (ln.price_per_unit.blank? ? 0 : ln.price_per_unit)).round(2)}
    raise "Unexpected order total. Got #{actual.to_s}, expected #{expected.to_s}" unless expected == actual
  end

  def process_line order, line_el
    line_number = et(line_el,'POSEX').to_i

    ol = order.order_lines.find {|ord_line| ord_line.line_number==line_number}
    ol = order.order_lines.build(line_number:line_number) unless ol

    ol.product = find_product(line_el)
    ol.quantity = BigDecimal(et(line_el,'MENGE'))

    # price might not be sent.  If it is, use it to get the price_per_unit, otherwise clear the price
    price_per_unit = nil
    extended_cost_text = et(line_el,'NETWR')
    if !extended_cost_text.blank?
      extended_cost = BigDecimal(extended_cost_text)
      price_per_unit = extended_cost / ol.quantity
    end
    ol.price_per_unit = price_per_unit 

    exp_del = expected_delivery_date(line_el)
    if !@first_expected_delivery_date || (exp_del && exp_del < @first_expected_delivery_date)
      order.first_expected_delivery_date = exp_del
      @first_expected_delivery_date = exp_del
    end
  end
  private :process_line

  def find_product order_line_el
    product_base = REXML::XPath.first(order_line_el,'E1EDP19')
    prod_uid = et(product_base,'IDTNR')
    return Product.where(unique_identifier:prod_uid).first_or_create!(
      importer:@imp,
      name:et(product_base,'KTEXT')
    )
  end

  def order_date base
    el = REXML::XPath.first(base,"./E1EDK03[IDDAT = '012']")
    return nil unless el
    str = et(el,'DATUM')
    return nil if str.blank?
    parse_date(str)
  end
  private :order_date

  def expected_delivery_date base
    el = REXML::XPath.first(base,"./E1EDP20")
    return nil unless el
    str = et(el,'EDATU')
    return nil if str.blank?
    parse_date(str)
  end

  def parse_date str
    return Date.new(str[0,4].to_i,str[4,2].to_i,str[6,2].to_i)
  end
  private :parse_date

  def extract_time envelope_element
    date_part = et(envelope_element,'CREDAT')
    time_part = et(envelope_element,'CRETIM')

    # match ActiveSupport::TimeZone.parse
    formatted_date = "#{date_part[0,4]}-#{date_part[4,2]}-#{date_part[6,2]} #{time_part[0,2]}:#{time_part[2,2]}:#{time_part[4,2]}"

    ActiveSupport::TimeZone['Eastern Time (US & Canada)'].parse(formatted_date)
  end
  private :extract_time
end; end; end; end