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
    @cdefs = self.class.prep_custom_definitions [:ord_sap_extract, :ord_type, :ord_buyer_name, :ord_buyer_phone]
    @opts = opts
  end

  def parse_dom dom
    @first_expected_delivery_date = nil
    root = dom.root
    raise "Incorrect root element #{root.name}, expecting 'ORDERS05'." unless root.name == 'ORDERS05'

    base = REXML::XPath.first(root,'IDOC')

    # order header info
    order_header = REXML::XPath.first(base,'E1EDK01')
    order_number = et(order_header,'BELNR')
    vendor_system_code = et(order_header,'RECIPNT_NO')

    # envelope info
    envelope = REXML::XPath.first(root,'//IDOC/EDI_DC40')
    ext_time = extract_time(envelope)

    find_order(order_number, @imp, ext_time) do |o|

      # creating the vendor shell record if needed and putting the SAP code as the name since we don't have anything better to use
      vend = nil
      Lock.acquire("Vendor-#{vendor_system_code}") do
        vend = Company.where(system_code:vendor_system_code).first_or_create!(vendor:true,name:vendor_system_code)
        @imp.linked_companies << vend unless @imp.linked_companies.include?(vend)
      end

      o.last_file_bucket = @opts[:bucket]
      o.last_file_path = @opts[:key]

      o.vendor = vend
      o.order_date = order_date(base)
      o.currency = et(order_header,'CURCY')
      o.terms_of_payment = payment_terms_description(base)
      o.terms_of_sale = ship_terms(base)
      o.order_from_address = order_from_address(base,vend)

      header_ship_to = ship_to_address(base,@imp)

      order_lines_processed = []
      REXML::XPath.each(base,'./E1EDP01') {|el| order_lines_processed << process_line(o, el, @imp, header_ship_to).line_number.to_i}
      o.order_lines.each {|ol|
        ol.mark_for_destruction unless order_lines_processed.include?(ol.line_number.to_i)
      }


      o.save!
      o.update_custom_value!(@cdefs[:ord_type],et(order_header,'BSART'))
      o.update_custom_value!(@cdefs[:ord_sap_extract],ext_time)
      buyer_name, buyer_phone = buyer_info(base)
      o.update_custom_value!(@cdefs[:ord_buyer_name],buyer_name)
      o.update_custom_value!(@cdefs[:ord_buyer_phone],buyer_phone)
      o.associate_vendor_and_products! @user

      o.reload
      validate_line_totals(o,base)

      o.create_snapshot @user
    end
  end

  private

    def find_order order_number, importer, extract_time
      o = nil
      Lock.acquire("LUMBER-#{order_number}") do
        po = Order.where(order_number: order_number).first_or_create! importer: importer

        if process_file?(extract_time, po)
          Lock.with_lock_retry(po) do
            o = yield po
          end
        end
      end
      o
    end

    def process_file? extract_time, order
      previous_extract_time = order.get_custom_value(@cdefs[:ord_sap_extract]).value

      # We only want to process the file if there was no previous process time, OR the current extract is after (or equal to) the previous time
      return previous_extract_time.nil? || extract_time.to_i >=  previous_extract_time.to_i
    end

    def validate_line_totals order, base_el
      expected_el = REXML::XPath.first(base_el,'E1EDS01/SUMME')
      return true if expected_el.nil?
      expected = BigDecimal(expected_el.text)
      actual = order.order_lines.inject(BigDecimal('0.00')) {|mem,ln| mem + BigDecimal(ln.quantity * (ln.price_per_unit.blank? ? 0 : ln.price_per_unit)).round(2)}
      raise "Unexpected order total. Got #{actual.to_s}, expected #{expected.to_s}" unless expected == actual
    end

    def process_line order, line_el, importer, header_ship_to
      line_number = et(line_el,'POSEX').to_i

      ol = order.order_lines.find {|ord_line| ord_line.line_number==line_number}
      ol = order.order_lines.build(line_number:line_number,total_cost_digits:2) unless ol

      ol.product = find_product(line_el)
      ol.quantity = BigDecimal(et(line_el,'MENGE'),4)
      ol.unit_of_measure = et(line_el,'MENEE')

      # price might not be sent.  If it is, use it to get the price_per_unit, otherwise clear the price
      price_per_unit = nil
      extended_cost_text = et(line_el,'NETWR')
      if !extended_cost_text.blank?
        extended_cost = BigDecimal(extended_cost_text,4)
        price_per_unit = extended_cost / ol.quantity
      end
      ol.price_per_unit = price_per_unit

      exp_del = expected_delivery_date(line_el)
      if !@first_expected_delivery_date || (exp_del && exp_del < @first_expected_delivery_date)
        order.first_expected_delivery_date = exp_del
        @first_expected_delivery_date = exp_del
      end

      ol.ship_to = ship_to_address(line_el,importer)

      ol.ship_to = header_ship_to if ol.ship_to.nil?

      return ol
    end

    def find_product order_line_el
      product_base = REXML::XPath.first(order_line_el,'E1EDP19')
      prod_uid = et(product_base,'IDTNR')
      return Product.where(unique_identifier:prod_uid).first_or_create!(
        importer:@imp,
        name:et(product_base,'KTEXT')
      )
    end

    def ship_terms base
      el = REXML::XPath.first(base,"./E1EDK17[QUALF = '001']")
      return nil unless el
      str = et(el,'LKOND')
      return str.blank? ? nil : str
    end

    def buyer_info base
      el = REXML::XPath.first(base,"./E1EDKA1[PARVW = 'AG']")
      return [nil,nil] unless el
      return [et(el,'BNAME'),et(el,'TELF1')]
    end

    def order_date base
      el = REXML::XPath.first(base,"./E1EDK03[IDDAT = '012']")
      return nil unless el
      str = et(el,'DATUM')
      return nil if str.blank?
      parse_date(str)
    end

    def order_from_address base, vendor
      vendor.addresses.first
    end

    def ship_to_address base, importer
      el = REXML::XPath.first(base,"./E1EDPA1[PARVW = 'WE']")
      return address(el,importer)
    end

    def address el, company
      return nil unless el
      my_addr = Address.new
      my_addr.company_id = company.id

      name1 = et(el,'NAME1')
      name2 = et(el,'NAME2')
      my_addr.name = name2.blank? ? name1 : name2

      my_addr.line_1 = et(el,'STRAS')
      my_addr.line_2 = et(el,'STRS2')
      my_addr.city = et(el,'ORT01')
      my_addr.state = et(el,'REGIO')
      my_addr.postal_code = et(el,'PSTLZ')

      country_iso = et(el,'LAND1')
      my_addr.country = Country.find_by_iso_code(country_iso) unless country_iso.blank?

      my_addr.system_code = et(el,'LIFNR')

      hk = Address.make_hash_key my_addr

      existing = company.addresses.find_by_address_hash hk

      return existing if existing

      my_addr.save!

      return my_addr
    end

    def expected_delivery_date base
      el = REXML::XPath.first(base,"./E1EDP20")
      return nil unless el
      str = et(el,'EDATU')
      return nil if str.blank?
      parse_date(str)
    end

    def payment_terms_description base
      # Use the ZTERM element to determine if there a special term codes that we need to handle
      # outside of the standard path of parsing the terms elements into a terms description.
      # Special Terms don't have these elements.
      zterm = REXML::XPath.first(base, "./E1EDK01/ZTERM").try(:text)
      if special_payment_terms[zterm]
        special_payment_terms[zterm]
      else
        elements = REXML::XPath.match(base,"./E1EDK18")

        # According to the doc from LL, If no E1DK18 is present, then order is due immediately.
        return "Due Immediately" unless elements.try(:size) > 0

        values = []
        elements.each do |el|
          days = et(el, 'TAGE')
          percent = et(el, 'PRZNT')

          next if days.blank?

          if percent.blank?
            values << "Net #{days}"
          else
            # Strip trailing insignificant digits
            if percent =~ /\.\d*[0]+$/
              percent.sub!(/0+$/, "")
              percent = percent[0..-2] if percent.ends_with?(".")
            end
            values << "#{percent}% #{days} Days"
          end
        end

        values.join(", ")
      end
    end

    def special_payment_terms
      {"TT00" => "T/T At Sight", "TT30" => "T/T Net 30"}
    end

    def parse_date str
      return Date.new(str[0,4].to_i,str[4,2].to_i,str[6,2].to_i)
    end

    def extract_time envelope_element
      date_part = et(envelope_element,'CREDAT')
      time_part = et(envelope_element,'CRETIM')

      # match ActiveSupport::TimeZone.parse
      formatted_date = "#{date_part[0,4]}-#{date_part[4,2]}-#{date_part[6,2]} #{time_part[0,2]}:#{time_part[2,2]}:#{time_part[4,2]}"

      ActiveSupport::TimeZone['Eastern Time (US & Canada)'].parse(formatted_date)
    end

end; end; end; end
