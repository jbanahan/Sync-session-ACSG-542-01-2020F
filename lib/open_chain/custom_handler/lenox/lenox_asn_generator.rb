require 'open_chain/fixed_position_generator'
require 'open_chain/custom_handler/lenox/lenox_custom_definition_support'
require 'open_chain/ftp_file_support'

module OpenChain; module CustomHandler; module Lenox; class LenoxAsnGenerator
  include OpenChain::CustomHandler::Lenox::LenoxCustomDefinitionSupport
  include OpenChain::FtpFileSupport

  class LenoxBusinessLogicError < StandardError; end

  SYNC_CODE = 'LENOXASN'

  def self.run_schedulable opts={}
    g = self.new(opts)
    temps = g.generate_tempfiles g.find_shipments
    g.ftp_file temps[0], {remote_file_name:'Vand_Header'}
    g.ftp_file temps[1], {remote_file_name:'Vand_Detail'}
  end

  def initialize opts = {}
    inner_opts = {'env'=>Rails.env}.merge opts
    @lenox = Company.find_by_system_code 'LENOX'
    @cdefs = self.class.prep_custom_definitions CUSTOM_DEFINITION_INSTRUCTIONS.keys
    @f = OpenChain::FixedPositionGenerator.new(exception_on_truncate:true,
      date_format:'%Y%m%d'
    )
    @env = inner_opts['env']
  end

  def ftp_credentials
    {server:'ftp.lenox.com',username:"vanvendor#{@env=='production' ? '' : 'test'}",password:'$hipments',folder:'.'}
  end

  def find_shipments
    Shipment.select("DISTINCT shipments.*").joins("LEFT OUTER JOIN sync_records ON sync_records.syncable_type = 'Shipment' AND sync_records.syncable_id = shipments.id AND sync_records.trading_partner = '#{SYNC_CODE}'").
      where(importer_id:@lenox.id).
      where('sync_records.id is null')
  end

  def generate_tempfiles shipments
    Shipment.transaction do
      header_file = Tempfile.new(['LENOXHEADER','.txt'])
      detail_file = Tempfile.new(['LENOXDETAIL','.txt'])
      shipments.each do |shp|
        hdata = ''
        ddata = ''
        generate_header_rows(shp) {|r| hdata << "#{r}\n"}
        generate_detail_rows(shp) {|r| ddata << "#{r}\n"}
        shp.sync_records.create!(sent_at:1.second.ago,confirmed_at:0.seconds.ago,confirmation_file_name:'MOCK',trading_partner:SYNC_CODE)
        header_file << hdata
        detail_file << ddata
      end
      header_file.flush
      detail_file.flush
      [header_file,detail_file]
    end
  end

  def generate_header_rows shipment
    header_hash = {}
    shipment.shipment_lines.each do |sl|
      key = "#{shipment.house_bill_of_lading}#{sl.order_lines.first.order.vendor.system_code.gsub("LENOX-",'')}#{sl.container.container_number}"
      header_hash[key] ||= []
      header_hash[key] << sl
    end
    header_hash.values.each do |sl_array|
      weight = sl_array.inject(BigDecimal('0.00')) {|i,sl| i+(sl.gross_kgs.nil? ? 0 : sl.gross_kgs)}
      cbms = sl_array.inject(BigDecimal('0.00')) {|i,sl| i+(sl.cbms.nil? ? 0 : sl.cbms)}
      cartons = sl_array.inject(0) { |mem, sl| mem+(sl.carton_qty.nil? ? 0 : sl.carton_qty) }
      container = sl_array.first.container
      r = ""
      r << "ASNH"
      r << @f.str(shipment.house_bill_of_lading,35)
      r << @f.str(sl_array.first.order_lines.first.order.vendor.system_code.gsub("LENOX-",''),8)
      r << @f.str(container.container_number,17)
      r << @f.str(container.container_size[2,container.container_size.length-2].gsub("'",''),10)
      r << @f.num(weight,10,3)
      r << @f.str('KG',10)
      r << @f.num(cbms,7,0) #TODO cubic meters
      r << @f.str(shipment.vessel,18)
      r << (cbms > 20 ? "Y" : "N")
      r << @f.num(cartons,7,0)
      r << @f.str(container.seal_number,35)
      r << @f.str('',25) #not going to have entry number
      r << @f.str('',20) #not going to have P Number
      r << @f.str('',16) #hold for ex-factory & gate in dates
      r << @f.date(shipment.est_departure_date)
      r << @f.str(shipment.lading_port.schedule_k_code,10)
      r << @f.str(shipment.unlading_port.schedule_d_code,10)
      r << @f.str('11',6) #only sending ocean
      r << @f.str(sl_array.first.order_lines.first.get_custom_value(@cdefs[:order_line_destination_code]).value,10)
      r << 'APP '
      r << ''.ljust(80)
      r << time_and_user
      yield r
    end
  end

  def generate_detail_rows shipment
    shipment.shipment_lines.each_with_index do |ln,i|
      order_line = ln.order_lines.first
      order = order_line.order
      r = "ASND"
      r << @f.str(shipment.house_bill_of_lading,35)
      r << @f.str(ln.container.container_number,17)
      r << @f.num(i+1,10)
      r << @f.str(order.get_custom_value(@cdefs[:order_factory_code]).value,10)
      r << @f.str(order.customer_order_number,35)
      r << @f.str(ln.product.unique_identifier.gsub("LENOX-",""),35)
      r << @f.num(get_exploded_quantity(ln),7)
      r << @f.str(ln.product.get_custom_value(@cdefs[:product_coo]).value,4)
      r << @f.str('',35) #no commercial invoice number
      r << @f.num(ln.line_number,10)
      r << @f.date(nil) #no invoice date
      r << ''.ljust(88)
      r << time_and_user
      r << @f.num(order_line.price_per_unit,18,6)
      r << @f.num(order_line.price_per_unit,18,6)
      r << @f.str(order.vendor.system_code.gsub('LENOX-',''),8)
      yield r
    end
  end

  private
  def get_exploded_quantity s_line
    p = s_line.product
    piece_factor = p.get_custom_value(@cdefs[:product_units_per_set]).value
    piece_factor = 1 if piece_factor.nil? || piece_factor < 1
    s_line.quantity / piece_factor
  end
  def time_and_user
    "#{@f.date(Time.now,'%Y%m%d%H%M%S')}#{@f.str((Rails.env.production? ? 'vanvendor' : 'vanvendortest'),15) }"
  end
  def get_vendor_code_and_invoices shipment
    h = {}
    entry.commercial_invoices.each do |ci|
      po_numbers = ci.commercial_invoice_lines.pluck('DISTINCT po_number')
      po_numbers = po_numbers.collect {|p| "LENOX-#{p}"}
      orders = Order.where("order_number in (?)",po_numbers).where(importer_id:@lenox.id).to_a
      raise LenoxBusinessLogicError.new("Order numbers #{po_numbers} only matched #{orders.size} orders for entry #{entry.entry_number}") if po_numbers.size != orders.size
      c = orders.first.vendor
      #strip the LENOX- prefix from the sytem code to get the lenox internal code
      #see the LenoxPoParser to see how these are created
      vendor_code = c.system_code.gsub('LENOX-','') 
      h[vendor_code] ||= []
      h[vendor_code] << ci
    end
    h
  end

  def lcl? entry
    entry.container_sizes.match /LCL/
  end

end; end; end; end
