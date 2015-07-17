module OpenChain; module CustomHandler; class ShipmentDownloadGenerator

  def initialize(shipment_id, user)
    @shipment = Shipment.find(shipment_id)
    @user = user
    @workbook = XlsMaker.new_workbook
    @next_row = 0
  end

  def generate
    @shipment.containers.each do |container|
      sheet = XlsMaker.create_sheet(@workbook, container.container_number)
      add_headers(sheet, container)
      container_lines = ShipmentLine.where(shipment_id: shipment.id, container_id: container.id).to_a
      add_lines_to_sheet(container_lines, sheet)
    end
    @workbook
  end

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
    XlsMaker.set_cell_value(sheet,0,9,"Container Number")
    XlsMaker.set_cell_value(sheet,1,9,container.container_number)
    XlsMaker.set_cell_value(sheet,0,10,"Container Size")
    XlsMaker.set_cell_value(sheet,1,10,container.container_size)
    XlsMaker.set_cell_value(sheet,0,11,"Seal Number")
    XlsMaker.set_cell_value(sheet,1,11,container.seal_number)
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

    ]

    add_header_rows(fields_to_add, sheet)
  end

  def add_lines_to_sheet(lines, sheet)
    lines.each { |line| add_line_to_sheet(line, sheet) }
  end

  def add_line_to_sheet(line, sheet)

  end

  def add_row(sheet, data)
    XlsMaker.add_body_row(sheet,@next_row,labels)
    @next_row += 1
  end

  def filler
    "this does nothing but fixes indentation"
  end

end; end; end