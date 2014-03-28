require 'open_chain/fixed_position_generator'
require 'open_chain/custom_handler/lenox/lenox_custom_definition_support'
module OpenChain; module CustomHandler; module Lenox; class LenoxAsnGenerator
  include OpenChain::CustomHandler::Lenox::LenoxCustomDefinitionSupport

  class LenoxBusinessLogicError < StandardError; end
  def initialize
    @lenox = Company.find_by_system_code 'LENOX'
    @cdefs = self.class.prep_custom_definitions CUSTOM_DEFINITION_INSTRUCTIONS.keys
    @f = OpenChain::FixedPositionGenerator.new(exception_on_truncate:true,
      date_format:'%Y%m%d'
    )
  end

  def generate_temp_files entries
    header_file = Tempfile.new(['LENOXHEADER','.txt'])
    detail_file = Tempfile.new(['LENOXDETAIL','.txt'])
    entries.each do |ent|
      generate_header_rows(ent) {|r| header_file << "#{r}\n"}
      generate_detail_rows(ent) {|r| detail_file << "#{r}\n"}
    end
    header_file.flush
    detail_file.flush
    [header_file,detail_file]
  end

  def generate_header_rows entry
    get_vendor_codes(entry).each do |vendor_code|
      yield build_header_row(entry,vendor_code,build_mode_specific_values(entry))
    end
  end

  def generate_detail_rows entry
    vals = build_mode_specific_values(entry)
    entry.commercial_invoice_lines.each_with_index do |ln,i|
      r = "ASND"
      r << @f.str(entry.master_bills_of_lading,35)
      r << @f.str(vals[:cnum],17)
      r << @f.num(i+1,9)
      r << @f.str(get_order_custom_value(:order_factory_code,ln),10)
      r << @f.str(ln.po_number,10)
      r << @f.str(ln.part_number,18)
      r << @f.num(get_exploded_quantity(ln),7)
      r << @f.str(ln.country_origin_code,4)
      r << ''.ljust(126)
      r << time_and_user
      yield r
    end
  end

  private
  def get_exploded_quantity ci_line
    p = Product.find_by_unique_identifier("LENOX-#{ci_line.part_number.strip}")
    if p.nil?
      raise LenoxBusinessLogicError.new("Product could not be found with unique identifier LENOX-#{ci_line.part_number.strip}")
    end
    piece_factor = p.get_custom_value(@cdefs[:product_units_per_set]).value
    piece_factor = 1 if piece_factor.nil? || piece_factor < 1
    ci_line.quantity * piece_factor
  end
  def build_mode_specific_values entry
    if entry.transport_mode_code == '11'
      if entry.containers.size != 1
        # temporary business logic exception until we figure out how to handle 
        # multiple containers
        raise LenoxBusinessLogicError.new("ASN cannot be generated for entry #{entry.entry_number} because it has multiple containers.")
      end
      cont = entry.containers.first
      return {
        cnum:cont.container_number,
        csize:cont.container_size,
        weight:cont.weight,
        cartons:cont.quantity,
        seal:cont.seal_number,
        fcl:(cont.fcl_lcl=='F' ? 'Y' : 'N')
      }
    else
      vals = {
        cnum:entry.house_bills_of_lading,
        weight:entry.gross_weight,
        cartons:entry.total_packages,
        fcl:'N'
      }
    end
  end
  def build_header_row entry, vendor_code, vals
    r = ""
    r << "ASNH"
    r << @f.str(entry.master_bills_of_lading,35)
    r << @f.str(vendor_code,8)
    r << @f.str(vals[:cnum],17)
    r << @f.str(vals[:csize],10)
    r << @f.num(vals[:weight],10,3)
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
    r << @f.str(entry.transport_mode_code,5)
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
    get_order_custom_value(:order_destination_code,entry.commercial_invoice_lines.first)
  end
  def get_order_custom_value cval_identifier, ci_line
    ord = Order.find_by_importer_id_and_order_number(@lenox.id,ci_line.po_number)  
    ord.get_custom_value(@cdefs[cval_identifier]).value
  end
  def get_vendor_codes entry
    po_numbers = entry.commercial_invoice_lines.pluck('DISTINCT po_number')
    orders = Order.where("order_number in (?)",po_numbers).where(importer_id:@lenox.id).to_a
    raise LenoxBusinessLogicError.new("Order numbers #{po_numbers} only matched #{orders.size} orders for entry #{entry.entry_number}") if po_numbers.size != orders.size
    vendor_codes = Company.where("id IN (?)",orders.collect {|o| o.vendor_id}).collect do |c|
      #strip the LENOX- prefix from the sytem code to get the lenox internal code
      #see the LenoxPoParser to see how these are created
      c.system_code.gsub('LENOX-','') 
    end
    vendor_codes
  end

end; end; end; end
