require 'rexml/document'
require 'open_chain/custom_handler/xml_helper'
require 'open_chain/custom_handler/generic/generic_custom_definition_support'

module OpenChain; module CustomHandler; module Generic; class LaceySimplifiedOrderXmlParser
  include OpenChain::CustomHandler::XmlHelper
  include OpenChain::CustomHandler::Generic::GenericCustomDefinitionSupport

  def self.parse_file data, log, opts={}
    self.new(opts).parse_dom REXML::Document.new(data), log
  end

  def initialize opts={}
    @cdefs = self.class.prep_custom_definitions [:ordln_country_of_harvest,:prod_genus,:prod_species,:prod_cites]
  end

  def parse_dom dom, log
    root = dom.root
    log.error_and_raise "XML has invalid root element \"#{root.name}\", expecting \"Order\"" unless root.name=='Order'

    importer = find_importer(root, log)
    log.company = importer
    ord = find_or_build_order(root, importer, log)
    if old_file?(root, ord, log)
      log.add_info_message "Order not updated: file contained outdated info."
      return
    end
    vendor = find_or_create_vendor(root, log)
    ship_from = find_or_create_address(vendor,REXML::XPath.first(root,'Address[@type="ship-from"]'), log)
    REXML::XPath.each(root,'OrderLine/Address[@type="ship-to"]') {|address_el| find_or_create_address(importer,address_el, log) }
    
    # pre-build the products outside of the parser lock
    prep_products(root, log)
    Lock.acquire("GenericOrderParser-#{ord.order_number}") do
      ord.vendor = vendor
      set_attribute_if_sent(ord,:customer_order_number,root,'CustomerOrderNumber')
      set_attribute_if_sent(ord,:order_date,root,'OrderDate')
      set_attribute_if_sent(ord,:customer_order_status,root,'CustomerOrderStatus')
      set_attribute_if_sent(ord,:last_exported_from_source,root,'SystemExtractDate')
      set_attribute_if_sent(ord,:mode,root,'Mode')
      set_attribute_if_sent(ord,:ship_window_start,root,'ShipWindowStartDate')
      set_attribute_if_sent(ord,:ship_window_end,root,'ShipWindowEndDate')
      set_attribute_if_sent(ord,:first_expected_delivery_date,root,'FirstExpectedDeliveryDate')
      set_attribute_if_sent(ord,:fob_point,root,'HandoverPoint')
      set_attribute_if_sent(ord,:closed_at,root,'ClosedDate')
      set_attribute_if_sent(ord,:terms_of_sale,root,'TermsOfSale')
      set_attribute_if_sent(ord,:terms_of_payment,root,'TermsOfPayment')
      set_attribute_if_sent(ord,:currency,root,'Currency')

      ord.ship_from = ship_from if ship_from

      built_lines = []
      REXML::XPath.each(root,'OrderLine') {|line_el| built_lines << build_line(ord, line_el, log)}
      delete_unused_lines(ord,built_lines)

      ord.save!
      ord.reload
      log.set_identifier_module_info InboundFileIdentifier::TYPE_PO_NUMBER, Order.to_s, ord.id
      validate_required_fields(ord, log)
      validate_totals(ord,REXML::XPath.first(root,'Summary'), log)
      ord.create_snapshot(User.integration,nil,"Lacey Simplified Order XML Parser")
    end
  end

  def old_file? element, ord, log
    sys_extract = et(element,'SystemExtractDate')
    log.reject_and_raise "SystemExtractDate is required" if sys_extract.blank?
    sys_ext_d = sys_extract.to_datetime
    return ord.last_exported_from_source && ord.last_exported_from_source > sys_ext_d
  end

  def delete_unused_lines ord, built_lines
    built_line_numbers = built_lines.map {|bl| bl.line_number.to_s}
    ord.order_lines.each do |ol|
      ol.destroy if !built_line_numbers.include?(ol.line_number.to_s)
    end
  end

  def validate_required_fields ord, log
    # checking these against the actual object since we are ok if the XML
    # is missing the element on an update if we already have the value
    log.reject_and_raise "CustomerOrderNumber is required" if ord.customer_order_number.blank?
    log.reject_and_raise "OrderDate is required" if ord.order_date.blank?
  end

  def validate_totals ord, element, log
    tl_num = et(element,'TotalLines').to_i
    olc = ord.order_lines.length
    if olc != tl_num
      log.reject_and_raise "TotalLines was #{tl_num} but order had #{olc} lines."
    end

    qty_val = et(element,'Quantity')
    if !qty_val.blank? #this is an optional validation
      total_quantity = ord.order_lines.inject(BigDecimal('0.0000')) {|i,ol| i + ol.quantity}
      if total_quantity != BigDecimal(qty_val)
        log.reject_and_raise "Summary Quantity was #{qty_val} but actual total was #{total_quantity}"
      end
    end

  end

  def find_importer dom, log
    sys_code = et(dom,'ImporterId')
    log.reject_and_raise "ImporterId is required" if sys_code.blank?
    imp = Company.where(importer:true,system_code:sys_code).first
    log.reject_and_raise "Importer was not found for ImporterId \"#{sys_code}\"" unless imp
    imp
  end

  def find_or_create_vendor dom, log
    sys_code = et(dom,'VendorNumber')
    log.reject_and_raise "VendorNumber is required" if sys_code.blank?

    ven  = nil
    Lock.acquire("Company-#{sys_code}") do
      need_save = false
      ven = Company.where(vendor:true,system_code:sys_code).first

      if(ven.nil?)
        ven = Company.new(vendor:true,system_code:sys_code,name:sys_code)
        need_save = true
      end
      # update the vendor name
      ven_name = et(dom,'VendorName')
      if !ven_name.blank? && ven.name!=ven_name
        ven.name = ven_name
        need_save = true
      end

      if need_save
        ven.save!
        ven.create_snapshot(User.integration,nil,"Lacey Simplified Order XML Parser")
      end

    end
    ven
  end

  def find_or_build_order dom, importer, log
    ord_num = et(dom,'OrderNumber')
    log.reject_and_raise "OrderNumber is required" if ord_num.blank?
    ord = Order.find_by_order_number(ord_num)
    ord = Order.new(order_number:ord_num,importer:importer) unless ord
    log.add_identifier InboundFileIdentifier::TYPE_PO_NUMBER, ord_num, module_type:Order.to_s, module_id:ord.id
    ord
  end

  def set_attribute_if_sent obj, obj_attr_name, dom, xpath
    val = et(dom,xpath)
    return if val.nil?
    data_type = obj.column_for_attribute(obj_attr_name).type
    case data_type
    when :datetime
      val = val.to_datetime
    end
    obj[obj_attr_name] = val
  end

  def find_or_create_address company, element, log
    return nil if element.nil?
    # Build a shell address and calculate the hash, then see if we have it in the DB
    # already. If so, use the DB version, otherwise, save and return the shell.
    shell = Address.new(
      name:et(element,'Name'),
      line_1: et(element,'Line1'),
      line_2: et(element,'Line2'),
      line_3: et(element,'Line3'),
      city: et(element,'City'),
      state: et(element,'State'),
      postal_code: et(element,'PostalCode'),
      country_id: find_country_id_by_iso(et(element, 'Country'), log),
      company_id:company.id,
      shipping:true
    )
    hash_key = Address.make_hash_key(shell)
    found_address = company.addresses.where(address_hash:hash_key).first
    if found_address.nil?
      shell.save!
      return shell
    else
      return found_address
    end
  end

  def find_country_id_by_iso iso, log
    return nil if iso.blank?
    c = Country.find_by_iso_code iso
    log.reject_and_raise "Country \"#{iso}\" not found" unless c
    return c.id
  end

  def build_line ord, element, log
    validate_required_line_fields(element, log)
    line_number = et(element,'LineNumber')
    log.reject_and_raise "LineNumber is required" if line_number.blank?
    ol = ord.order_lines.find {|ln| ln.line_number.to_s==line_number.to_s}
    ol = ord.order_lines.build(line_number:line_number) unless ol
    ol.product = find_or_create_product(ord.vendor,REXML::XPath.first(element,'Product'), log)
    set_attribute_if_sent(ol,:quantity,element,'OrderedQuantity')
    set_attribute_if_sent(ol,:price_per_unit,element,'PricePerUnit')
    set_attribute_if_sent(ol,:unit_of_measure,element,'UnitOfMeasure')
    set_attribute_if_sent(ol,:country_of_origin,element,'CountryOfOrigin')
    set_attribute_if_sent(ol,:hts,element,'HTSCode')
    set_attribute_if_sent(ol,:sku,element,'SKU')
    c_harv = et(element,'CountryOfHarvest')
    if !c_harv.nil?
      ol.find_and_set_custom_value(@cdefs[:ordln_country_of_harvest],c_harv)
    end
    ship_to = find_or_create_address(ord.importer,REXML::XPath.first(element,'Address[@type="ship-to"]'), log)
    ol.ship_to = ship_to if ship_to
    ol
  end

  def validate_required_line_fields element, log
    ['OrderedQuantity','PricePerUnit','UnitOfMeasure'].each do |txt|
      log.reject_and_raise "#{txt} is required" if et(element,txt).blank?
    end
  end

  def prep_products root, log
    REXML::XPath.each(root,'OrderLine/Product') do |element|
      uid = et(element,'UniqueIdentifier')
      log.reject_and_raise "OrderLine/Product/UniqueIdentifier is required" if uid.blank?
      Lock.acquire("Product-#{uid}") do
        need_snapshot = false
        p = Product.find_by_unique_identifier(uid)
        if p.nil?
          p = Product.create!(unique_identifier:uid)
          need_snapshot = true
        end
        p_name = et(element,'Name')
        if p_name!=nil && p.name != p_name
          p.update_attributes(name:p_name)
          need_snapshot = true
        end
        need_snapshot = true if update_product_custom_value(p,element,'Genus',:prod_genus)
        need_snapshot = true if update_product_custom_value(p,element,'Species',:prod_species)
        need_snapshot = true if update_product_custom_value(p,element,'CITES',:prod_cites,true)
        p.create_snapshot(User.integration,nil,"Lacey Simplified Order XML Parser") if need_snapshot
      end
    end
  end
  def find_or_create_product vendor, element, log
    uid = et(element,'UniqueIdentifier')
    log.reject_and_raise "OrderLine/Product/UniqueIdentifier is required" if uid.blank?
    p = Product.find_by_unique_identifier(uid)

    # this shouldn't happen since we're prepping the products in advance, but leaving the test
    # just in case
    log.reject_and_raise "Product #{p.unique_identifier} not found." unless p
    Lock.acquire("ProductVendorAssignment-#{p.id}-#{vendor.id}") do
      pva_qry = ProductVendorAssignment.where(product_id:p,vendor_id:vendor.id)
      if pva_qry.empty?
        pva = pva_qry.create!
        pva.create_snapshot(User.integration,nil,"Lacey Simplified Order XML Parser")
      end
    end
    p
  end

  def update_product_custom_value p, element, el_name, cdef_id, is_boolean=false
    el_val = et(element,el_name)
    if el_val!=nil
      el_val = (el_val=='Y') if is_boolean
      cd = @cdefs[cdef_id]
      cv = p.custom_value(cd)
      if cv!=el_val
        p.update_custom_value!(cd,el_val)
        return true
      end
    end
    return false
  end
end; end; end; end
