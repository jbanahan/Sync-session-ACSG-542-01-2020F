module OpenChain; module CustomHandler; class ShipmentDownloadGenerator
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def initialize(shipment, user)
    @shipment = shipment
    @user = user
    @workbook = XlsMaker.new_workbook
    @custom_defintions = self.class.prep_custom_definitions [:prod_part_number]

    raise "You can't download this shipment!" unless @shipment.can_view? @user
    raise "This shipment has no containers!" unless @shipment.containers.any?
  end

  def generate
    @shipment.containers.each do |container|
      sheet = new_sheet(container)
      add_headers(sheet, container)
      add_lines_to_sheet(container.shipment_lines, sheet)
    end
    file_for @workbook
  end

  private

  def new_sheet(container)
    @next_row = 0
    XlsMaker.create_sheet(@workbook, container.container_number)
  end

  def add_headers(sheet, container)
    add_first_header_rows(sheet)
    add_container_header_data(sheet, container)
    add_second_header_rows(sheet)
    2.times { add_row(sheet) }
  end

  def add_header_rows(uids, sheet)
    fields = uids.map { |uid| ModelField.find_by_uid uid }
    labels = fields.map(&:label)
    values = fields.map{ |field| field.process_export(@shipment, @user) }
    add_header_row(sheet, labels)
    add_row(sheet, values)
  end

  def add_container_header_data(sheet, container)
    insert_row(sheet,0,7,["Container Number","Container Size","Seal Number"])
    insert_row(sheet,1,7,[container.container_number,container.container_size,container.seal_number])
  end

  def add_first_header_rows(sheet)
    fields_to_add = [
      :shp_receipt_location,
      :shp_dest_port_name,
      :shp_final_dest_port_name,
      :shp_master_bill_of_lading,
      :shp_house_bill_of_lading,
      :shp_vessel,
      :shp_voyage
    ]

    add_header_rows(fields_to_add, sheet)
  end

  def add_second_header_rows(sheet)
    fields_to_add = [
      :shp_departure_date,
      :shp_confirmed_on_board_origin_date,
      :shp_eta_last_foreign_port_date,
      :shp_departure_last_foreign_port_date,
      :shp_est_arrival_port_date
    ]

    add_header_rows(fields_to_add, sheet)
  end

  def add_lines_to_sheet(lines, sheet)
    fields = [
      :con_container_number,
      :ord_cust_ord_no,
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
      :shp_docs_received_date
    ].map {|uid| ModelField.find_by_uid(uid) }.insert(2, @custom_defintions[:prod_part_number].model_field)

    add_header_row(sheet, fields.map(&:base_label))
    lines.each { |line| add_line_to_sheet(line, fields, sheet) }
    add_totals_to_sheet(lines, sheet)
  end

  def add_line_to_sheet(line, fields, sheet)
    order = line.order_lines.first.order
    values = [
      fields[0].process_export(line.container, @user),
      fields[1].process_export(order, @user),
      fields[2].process_export(line.order_lines.first.product, @user),
      fields[3].process_export(line, @user),
      fields[4].process_export(line, @user),
      fields[5].process_export(line, @user),
      fields[6].process_export(line, @user),
      fields[7].process_export(order, @user),
      fields[8].process_export(@shipment, @user),
      fields[9].process_export(@shipment, @user),
      fields[10].process_export(order, @user),
      fields[11].process_export(@shipment, @user),
      fields[12].process_export(@shipment, @user),
      fields[13].process_export(@shipment, @user)
    ]

    add_row(sheet, values)
  end

  def add_totals_to_sheet(lines, sheet)
    carton_qty_total = lines.sum {|line| line.carton_qty || 0}
    pieces_total = lines.sum {|line| line.quantity || 0}
    cbms_total = lines.sum {|line| line.cbms || 0}
    insert_row(sheet, @next_row, 4, [carton_qty_total, pieces_total, cbms_total])
  end


  def file_for(workbook)
    file = Tempfile.new([@shipment.reference, '.xls'])
    workbook.write file.path
    file
  end

  def add_header_row(sheet, data=[])
    XlsMaker.add_header_row(sheet, @next_row, data)
    @next_row += 1
  end

  def insert_row(sheet, row, column, data=[])
    XlsMaker.insert_body_row(sheet, row, column, data)
  end

  def add_row(sheet, data=[])
    XlsMaker.add_body_row(sheet,@next_row,data)
    @next_row += 1
  end

end; end; end