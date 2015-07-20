module OpenChain; module CustomHandler; class ShipmentDownloadGenerator

  def initialize(shipment_id, user)
    @shipment = Shipment.find(shipment_id)
    @user = user
    @workbook = XlsMaker.new_workbook

    raise "You can't download this shipment!" unless @shipment.can_view? @user
    raise "This shipment has no containers!" unless @shipment.containers.count > 0
  end

  def generate
    @shipment.containers.each do |container|
      @next_row = 0
      sheet = XlsMaker.create_sheet(@workbook, container.container_number)
      add_headers(sheet, container)
      2.times {add_row(sheet)}
      container_lines = ShipmentLine.where(shipment_id: @shipment.id, container_id: container.id).to_a
      add_container_header_data(sheet, container)
      add_lines_to_sheet(container_lines, sheet)
    end
    file_for @workbook
  end

  private

  def add_headers(sheet, container)
    add_first_header_rows(sheet)
    add_container_header_data(sheet, container)
    add_second_header_rows(sheet)
  end

  def add_header_rows(uids, sheet)
    fields = uids.map { |uid| ModelField.find_by_uid uid }
    labels = fields.map(&:label)
    values = fields.map{ |field| field.process_export(@shipment, @user) }
    add_row(sheet, labels)
    add_row(sheet, values)
  end

  def add_container_header_data(sheet, container)
    XlsMaker.insert_body_row(sheet,0,9,["Container Number","Container Size","Seal Number"])
    XlsMaker.insert_body_row(sheet,1,9,[container.container_number,container.container_size,container.seal_number])
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
      :nil, # Item style number?
      :shpln_manufacturer_address_name,
      :shpln_carton_qty,
      :shpln_shipped_qty,
      :shpln_cbms,
      :nil, #latest ship date?
      :shp_freight_terms,
      :shp_shipment_type,
      :nil, #PO delivery date?
      :shp_booking_received_date,
      :shp_cargo_on_hand_date,
      :shp_docs_received_date
    ].map {|uid| ModelField.find_by_uid(uid) }
    add_row(sheet, fields.map(&:label))

    lines.each { |line| add_line_to_sheet(line, fields, sheet) }
  end

  def add_line_to_sheet(line, fields, sheet)
    values = [
      line.container.container_number,
      line.order_lines.first.order.customer_order_number,
      #Item style number?
      fields[3].process_export(line, @user),
      fields[4].process_export(line, @user),
      fields[5].process_export(line, @user),
      fields[6].process_export(line, @user),
      #latest ship date?
      fields[8].process_export(@shipment, @user),
      fields[9].process_export(@shipment, @user),
      #PO delivery date?
      fields[11].process_export(@shipment, @user),
      fields[12].process_export(@shipment, @user),
      fields[13].process_export(@shipment, @user)
    ]

    add_row(sheet, values)
  end

  def file_for(workbook)
    file = Tempfile.new([@shipment.reference, '.xls'])
    workbook.write file.path
    file
  end

  def add_row(sheet, data=[])
    XlsMaker.add_body_row(sheet,@next_row,data)
    @next_row += 1
  end

end; end; end