require 'open_chain/custom_handler/lenox/lenox_custom_definition_support'
module OpenChain; module CustomHandler; module Lenox; class LenoxPoParser
  include OpenChain::CustomHandler::Lenox::LenoxCustomDefinitionSupport
  def initialize
    @cdefs = self.class.prep_custom_definitions CUSTOM_DEFINITION_INSTRUCTIONS.keys
    @imp = Company.where(system_code:'LENOX').first_or_create!(name:'Lenox',importer:true)
  end
  def process data
    order_lines = []
    last_order_number = []
    data.lines.each do |ln|
      next if ln.blank?
      ls = parse_line ln
      if ls.order_number != last_order_number
        process_order_lines order_lines unless order_lines.blank?
        order_lines = []
      end
      order_lines << ls
      last_order_number = ls.order_number
    end
    process_order_lines order_lines unless order_lines.blank?
  end
  private
  def process_order_lines lines
    ls = lines.first
    ord_relation = Order.where(importer_id:@imp.id,order_number:ls.order_number)
    if ls.delete?
      ord_relation.destroy_all 
      return
    end
    o = ord_relation.first_or_create!
    o.customer_order_number = ls.customer_order_number
    o.order_date = ls.order_date
    o.mode = ls.mode
    o.vendor = get_vendor(ls)
    o.save!

    #handle custom values after save
    o.update_custom_value! @cdefs[:order_buyer_name], ls.buyer_name
    o.update_custom_value! @cdefs[:order_buyer_email], ls.buyer_email
    o.update_custom_value! @cdefs[:order_destination_code], ls.destination_code
    o.update_custom_value! @cdefs[:order_factory_code], ls.factory_code

    #process lines
    lines.each do |ln|
      p = get_product ln
      ol = o.order_lines.where(line_number:ln.line_number).first_or_create!(product:p)
      ol.update_attributes(
        product:p, price_per_unit:ln.unit_price,quantity:ln.quantity,
        currency:ln.currency,country_of_origin:ln.coo,hts:ln.hts
      )
      ol.update_custom_value! @cdefs[:order_line_note], ln.line_note
    end
  end
  def get_product line_struct
    p = Product.where(importer_id:@imp.id,
      unique_identifier:line_struct.product_uid).
      first_or_create!(name:line_struct.part_name)
    p.update_custom_value! @cdefs[:part_number], line_struct.part_number
    if line_struct.earliest_ship_date
      cv = p.get_custom_value(@cdefs[:product_earliest_ship])
      if cv.value.blank? || cv.value > line_struct.earliest_ship_date
        cv.value = line_struct.earliest_ship_date
        cv.save!
      end
    end
    p
  end
  def get_vendor line_struct
    sys_code = "LENOX-#{line_struct.vendor_code}"
    v = Company.find_by_system_code(sys_code)
    if v.nil?
      v = Company.create!(system_code:sys_code,name:line_struct.vendor_name,vendor:true)
      @imp.linked_companies << v
    end
    v
  end
  LINE_STRUCT ||= Struct.new(:customer_order_number,:order_date,
    :line_number,:part_number,:part_name,:unit_price,:quantity,
    :currency,:transaction_type,:line_note,:buyer_name,:buyer_email,
    :earliest_ship_date,:destination_code,:hts,:coo,:mode,
    :vendor_code,:vendor_name,:factory_code) do
    def order_number
      "LENOX-#{self.customer_order_number}"
    end
    def product_uid
      "LENOX-#{self.part_number}"
    end
    def delete?
      self.transaction_type == 'D'
    end
  end
  def parse_line line
    r = LINE_STRUCT.new
    r.transaction_type = line[0]
    r.customer_order_number = line[18,8]
    r.order_date = parse_date(line[26,8])
    r.line_number = line[1073,2]
    r.part_number = line[1150,25].strip 
    r.part_name = line[1175,40].strip
    r.unit_price = parse_currency(line[1215,15])
    r.quantity = line[1235,15].strip
    r.currency = line[1230,3]
    r.line_note = line[34,70].strip
    r.buyer_name = line[202,25].strip
    r.buyer_email = line[227,35].strip
    r.earliest_ship_date = parse_date(line[262,8])
    r.destination_code = line[395,17].strip
    r.coo = line[2392,2].strip
    r.hts = line[2396,10].strip
    r.mode = line[1356,3].strip
    r.vendor_code = line[1669,17].strip
    r.vendor_name = line[1686,35].strip
    r.factory_code = line[2025,10].strip
    r
  end
  def parse_date str
    return nil unless str.match /^\d{8}$/
    Date.strptime(str,'%Y%m%d')
  end
  def parse_currency str
    return nil unless str.match /\d{2}$/
    BigDecimal("#{str[0,13].strip}.#{str[13,2]}")
  end
end; end; end; end
