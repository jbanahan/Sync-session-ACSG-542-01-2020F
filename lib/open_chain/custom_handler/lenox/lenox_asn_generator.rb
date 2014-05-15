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
    temps = g.generate_tempfiles g.find_entries
    g.ftp_file temps[0], {remote_file_name:'Vand_Header'}
    g.ftp_file temps[1], {remote_file_name:'Vand_Detail'}
  end

  def initialize opts = {env: Rails.env}
    @lenox = Company.find_by_system_code 'LENOX'
    @cdefs = self.class.prep_custom_definitions CUSTOM_DEFINITION_INSTRUCTIONS.keys
    @f = OpenChain::FixedPositionGenerator.new(exception_on_truncate:true,
      date_format:'%Y%m%d'
    )
    @env = opts[:env]
  end

  def ftp_credentials
    {server:'ftp.lenox.com',username:"vanvendor#{@env=='production' ? '' : 'test'}",password:'$hipments',folder:'.'}
  end

  def find_entries
    passed_rules = SearchCriterion.new(model_field_uid:'ent_rule_state',operator:'eq',value:'Pass')
    passed_rules.apply(Entry.select("DISTINCT entries.*").joins("LEFT OUTER JOIN sync_records ON sync_records.syncable_type = 'Entry' AND sync_records.syncable_id = entries.id AND sync_records.trading_partner = '#{SYNC_CODE}'").
      where(importer_id:@lenox.id).
      where("entries.entry_filed_date is not null").
      where('sync_records.id is null'))
  end

  def generate_tempfiles entries
    Entry.transaction do
      header_file = Tempfile.new(['LENOXHEADER','.txt'])
      detail_file = Tempfile.new(['LENOXDETAIL','.txt'])
      entries.each do |ent|
        begin
          Entry.transaction do
            hdata = ''
            ddata = ''
            generate_header_rows(ent) {|r| hdata << "#{r}\n"}
            generate_detail_rows(ent) {|r| ddata << "#{r}\n"}
            ent.sync_records.create!(sent_at:1.second.ago,confirmed_at:0.seconds.ago,confirmation_file_name:'MOCK',trading_partner:SYNC_CODE)
            header_file << hdata
            detail_file << ddata
          end
        rescue
          if $!.is_a?(LenoxBusinessLogicError)
            ent.sync_records.create!(sent_at:1.second.ago,confirmed_at:0.seconds.ago,confirmation_file_name:'LOGICERROR',trading_partner:SYNC_CODE)
          end
          OpenMailer.send_simple_html('lenox_us@vandegriftinc.com',
            "Lenox ASN Failure","<p>A Lenox ASN Failed with the following message:</p>
            <pre>#{$!.message}</pre><p>Please contact the Lenox on site team so they can manually enter the shipment and invoice into SCW / Rockblocks.</p>").deliver!
        end
      end
      header_file.flush
      detail_file.flush
      [header_file,detail_file]
    end
  end

  def generate_header_rows entry
    get_vendor_code_and_invoices(entry).each do |vendor_code,invoices|
      gross_weight = invoices.inject(0) {|r,inv| r + (inv.gross_weight.blank? ? 0 : inv.gross_weight)}
      yield build_header_row(entry,vendor_code,gross_weight,build_mode_specific_values(entry))
    end
  end

  def generate_detail_rows entry
    vals = build_mode_specific_values(entry)
    entry.commercial_invoice_lines.each_with_index do |ln,i|
      order_line = get_order_line(ln)
      raise LenoxBusinessLogicError.new("Order Line couldn't be found for order #{ln.po_number}, part #{ln.part_number}") if order_line.nil?
      r = "ASND"
      r << @f.str(entry.master_bills_of_lading,35)
      r << @f.str(vals[:cnum],17)
      r << @f.num(i+1,9)
      r << @f.str(get_order_custom_value(:order_factory_code,ln),10)
      r << @f.str(ln.po_number,35)
      r << @f.str(ln.part_number,35)
      r << @f.num(get_exploded_quantity(ln),7)
      r << @f.str(ln.country_origin_code,4)
      r << @f.str(ln.commercial_invoice.invoice_number,25)
      r << @f.num(ln.line_number,5)
      r << ''.ljust(96)
      r << time_and_user
      r << @f.num(order_line.price_per_unit,18,6)
      r << @f.num(ln.unit_price,18,6)
      yield r
    end
  end

  private
  def get_order_line(ln)
    OrderLine.joins([:order,:product]).where("products.unique_identifier = ?","LENOX-#{ln.part_number.strip}").where("orders.order_number = ?","LENOX-#{ln.po_number}").order('order_lines.line_number DESC').first
  end
  def get_exploded_quantity ci_line
    p = Product.find_by_unique_identifier("LENOX-#{ci_line.part_number.strip}")
    if p.nil?
      raise LenoxBusinessLogicError.new("Product could not be found with unique identifier LENOX-#{ci_line.part_number.strip}")
    end
    piece_factor = p.get_custom_value(@cdefs[:product_units_per_set]).value
    piece_factor = 1 if piece_factor.nil? || piece_factor < 1
    ci_line.quantity / piece_factor
  end
  def build_mode_specific_values entry
    if entry.transport_mode_code == '11' || entry.transport_mode_code == '10'
      if entry.containers.size != 1
        # temporary business logic exception until we figure out how to handle 
        # multiple containers
        raise LenoxBusinessLogicError.new("ASN cannot be generated for entry #{entry.entry_number} because it has multiple containers.")
      end
      cont = entry.containers.first
      return {
        cnum:cont.container_number,
        csize:cont.container_size,
        cartons:cont.quantity,
        seal:cont.seal_number,
        fcl:(entry.transport_mode_code=='11' ? 'Y' : 'N')
      }
    else
      vals = {
        cnum:entry.house_bills_of_lading,
        cartons:entry.total_packages,
        fcl:'N'
      }
    end
  end
  def build_header_row entry, vendor_code, gross_weight, vals
    r = ""
    r << "ASNH"
    r << @f.str(entry.master_bills_of_lading,35)
    r << @f.str(vendor_code,8)
    r << @f.str(vals[:cnum],17)
    r << @f.str(vals[:csize],10)
    r << @f.num(gross_weight,10,3)
    r << @f.str('KG',10)
    r << @f.num(0,7,0) #TODO cubic meters
    r << @f.str(entry.vessel,18)
    r << vals[:fcl]
    r << @f.num(vals[:cartons],7,0)
    r << @f.str(vals[:seal],35)
    r << @f.str(entry.entry_number,25)
    r << @f.str(entry.customer_references,20)
    r << @f.str('',16) #hold for ex-factory & gate in dates
    r << @f.date(entry.export_date)
    r << @f.str(entry.lading_port_code,10)
    r << @f.str(entry.unlading_port_code,10)
    r << @f.str('',6) #hold for mode
    r << @f.str(get_final_destination_code(entry),10)
    r << 'APP '
    r << ''.ljust(80)
    r << time_and_user
    r
  end
  def time_and_user
    "#{@f.date(Time.now,'%Y%m%d%H%M%S')}#{@f.str((Rails.env.production? ? 'vanvendor' : 'vanvendortest'),15) }"
  end
  def get_final_destination_code entry
    get_order_line(entry.commercial_invoice_lines.first).get_custom_value(@cdefs[:order_line_destination_code]).value
  end
  def get_order_custom_value cval_identifier, ci_line
    ord = get_order(ci_line)
    ord.get_custom_value(@cdefs[cval_identifier]).value
  end
  def get_order ci_line
    Order.find_by_importer_id_and_order_number(@lenox.id,"LENOX-#{ci_line.po_number}")  
  end
  def get_vendor_code_and_invoices entry
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

end; end; end; end
