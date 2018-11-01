require 'open_chain/report/report_helper'

module OpenChain; module CustomHandler; module JJill; class JJillShipmentDownloadGenerator
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def initialize
    @custom_definitions = self.class.prep_custom_definitions [:prod_part_number]
  end

  def generate shipment, user
    workbook = XlsMaker.new_workbook

    mode = shipment.mode.presence || shipment.booking_mode.presence
    if mode.to_s.upcase != "AIR" && shipment.containers.length > 0
      shipment.containers.each do |container|
        sheet = new_sheet(workbook, container)
        add_headers(sheet, shipment, user, container)
        rolled_up_lines = roll_up(shipment, user, container.shipment_lines)
        add_lines_to_sheet(rolled_up_lines, sheet)
      end
    else
      sheet = new_sheet(workbook)
      add_headers(sheet, shipment, user)
      rolled_up_lines = roll_up(shipment, user, shipment.shipment_lines)
      add_lines_to_sheet(rolled_up_lines, sheet) if rolled_up_lines.count > 0
    end

    workbook
  end

  private

  def line_fields
    [
      :con_container_number,
      :ord_cust_ord_no,
      [@custom_definitions[:prod_part_number], unique_identifier_lambda],
      :shpln_manufacturer_address_name,
      :shpln_carton_qty,
      :shpln_shipped_qty,
      :shpln_cbms,
      :ord_window_end,
      :shp_freight_terms,
      :shp_shipment_type,
      :ord_first_exp_del,
      :shp_booking_received_date,
      :shp_cargo_on_hand_date,
      :shp_docs_received_date,
      :shp_fish_and_wildlife,
      :ord_ship_to_system_code
    ]
  end

  def new_sheet(workbook, container=nil)
    @next_row = 0
    @column_widths = []
    sheet_name = container.try(:container_number) || 'Details'
    XlsMaker.create_sheet(workbook, sheet_name)
  end

  def add_headers(sheet, shipment, user, container=nil)
    add_first_header_rows(shipment, user, sheet)
    add_container_header_data(sheet, container) if container
    add_second_header_rows(shipment, user, sheet)
    2.times { add_row(sheet) }
  end

  def add_header_rows(shipment, user, uids, sheet)
    fields = uids.map { |uid| ModelField.find_by_uid uid }
    labels = fields.map(&:label)
    values = fields.map{ |field| field.process_export(shipment, user) }
    add_header_row(sheet, labels)
    add_row(sheet, values)
  end

  def add_container_header_data(sheet, container)
    insert_row(sheet,0,7,["Container Number","Container Size","Seal Number"])
    insert_row(sheet,1,7,[container.container_number,container.container_size,container.seal_number])
  end

  def add_first_header_rows(shipment, user, sheet)
    fields_to_add = [
      :shp_receipt_location,
      :shp_dest_port_name,
      :shp_final_dest_port_name,
      :shp_master_bill_of_lading,
      :shp_house_bill_of_lading,
      :shp_vessel,
      :shp_voyage
    ]

    add_header_rows(shipment, user, fields_to_add, sheet)
  end

  def add_second_header_rows(shipment, user, sheet)
    fields_to_add = [
        :shp_confirmed_on_board_origin_date,
        :shp_departure_date,
        :shp_eta_last_foreign_port_date,
        :shp_departure_last_foreign_port_date,
        :shp_est_arrival_port_date
    ]

    add_header_rows(shipment, user, fields_to_add, sheet)
  end

  def roll_up shipment, user, lines
    lines_by_order = Hash.new{|k,v| k[v] = [] }
    lines.each { |line| add_line_to_hsh(shipment, user, line, lines_by_order) }
    flatten lines_by_order
  end
  
  def flatten lines_by_order
    out = []
    lines_by_order.each_value do |lines|
      ord = Hash.new{|k,v| k[v] = [] }
      lines.each do |l|
        ord[:container_num] << l[0]
        ord[:cust_ord_num] << l[1]
        ord[:uid] << l[2]
        ord[:manufacturer_addr] << l[3]
        ord[:carton_qty] << l[4]
        ord[:shipped_qty] << l[5]
        ord[:cbms] << l[6]
        ord[:window_end] << l[7]
        ord[:freight_terms] << l[8]
        ord[:shipment_type] << l[9]
        ord[:first_exp_del] << l[10]
        ord[:booking_rec] << l[11]
        ord[:cargo_on_hand] << l[12]
        ord[:docs_rec] << l[13]
        ord[:fish_wildlife] << l[14]
        ord[:warehouse] << l[15]
      end
      out << [format_str(ord[:container_num]), format_str(ord[:cust_ord_num]), format_str(ord[:uid]), format_str(ord[:manufacturer_addr]), 
                         ord[:carton_qty].compact.sum, ord[:shipped_qty].compact.sum, ord[:cbms].compact.sum, ord[:window_end].max, 
                         format_str(ord[:freight_terms]), format_str(ord[:shipment_type]), ord[:first_exp_del].min, ord[:booking_rec].max.try(:strftime, '%Y-%m-%d'), 
                         ord[:cargo_on_hand].max, ord[:docs_rec].max, format_bool(ord[:fish_wildlife]), format_str(ord[:warehouse])]
    end
    out
  end

  def format_str arr
    arr.compact.sort.uniq.join(', ')
  end

  def format_bool arr
    arr.any? ? "Yes" : "No"
  end

  def add_lines_to_sheet(lines, sheet)
    add_header_row(sheet, line_fields.map {|f| field_label(f) })
    lines.each { |line| add_row(sheet, line) }
    add_totals_to_sheet(lines, sheet)
  end

  def add_line_to_hsh(shipment, user, line, out_hsh)
    order = line.order_lines.first.order
    cust_ord_num = field_value(line_fields[1], order, user)
    values = [
      field_value(line_fields[0], line.container, user),
      cust_ord_num,
      field_value(line_fields[2], line.order_lines.first.product, user),
      field_value(line_fields[3], line, user),
      field_value(line_fields[4], line, user),
      field_value(line_fields[5], line, user),
      field_value(line_fields[6], line, user),
      field_value(line_fields[7], order, user),
      field_value(line_fields[8], shipment, user),
      field_value(line_fields[9], shipment, user),
      field_value(line_fields[10], order, user),
      field_value(line_fields[11], shipment, user),
      field_value(line_fields[12], shipment, user),
      field_value(line_fields[13], shipment, user),
      field_value(line_fields[14], shipment, user),
      field_value(line_fields[15], order, user)
    ]
    out_hsh[cust_ord_num] << values
  end

  def add_totals_to_sheet(lines, sheet)
    carton_qty_total = lines.compact.sum {|line| line[4] || 0}
    pieces_total = lines.compact.sum {|line| line[5] || 0}
    cbms_total = lines.compact.sum {|line| line[6] || 0}
    insert_row(sheet, @next_row, 4, [carton_qty_total, pieces_total, cbms_total])
  end

  def add_header_row(sheet, data=[])
    XlsMaker.add_header_row(sheet, @next_row, data, @column_widths)
    @next_row += 1
  end

  def insert_row(sheet, row, column, data=[])
    XlsMaker.insert_body_row(sheet, row, column, data, @column_widths)
  end

  def add_row(sheet, data=[])
    XlsMaker.add_body_row(sheet,@next_row,data, @column_widths)
    @next_row += 1
  end

  def field_value field, object, user
    value = nil
    Array.wrap(field).each do |f|
      if f.respond_to?(:call)
        v = f.call(object, user)
      else
        v = mf(f).process_export object, user
      end

      if !v.blank?
        value = v
        break
      end
    end
    value
  end

  def replace_label label
    {"Fish And Wildlife" => "Fish & Wildlife Flag", "Ship To System Code" => "Warehouse Code"}[label] || label
  end

  def field_label field
    # Always just use the first model field value given
    f = field.respond_to?(:first) ? field.first : field
    replace_label mf(f).label(false)
  end

  def mf field
    field.respond_to?(:model_field) ? field.model_field : ModelField.find_by_uid(field)
  end

  def unique_identifier_lambda
    lambda do |prod, user|
      mf = ModelField.find_by_uid(:prod_uid)
      value = mf.process_export(prod, user)

      if !value.blank? && !prod.importer.system_code.blank?
        syscode = prod.importer.system_code

        # strip the system code from the front of the product if it's there
        value = value.sub(/^#{syscode}-/i, "")
      end

      value
    end
  end

end; end; end; end
