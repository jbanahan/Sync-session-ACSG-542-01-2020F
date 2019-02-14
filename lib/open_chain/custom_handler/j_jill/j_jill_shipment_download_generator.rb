require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module JJill; class JJillShipmentDownloadGenerator
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def generate builder, shipment, user
    mode = shipment.mode.presence || shipment.booking_mode.presence
    if mode.to_s.upcase != "AIR" && shipment.containers.length > 0
      # This grouping stuff is because user's can make multiple container records with the same container number.
      # If we don't handle this then because we use the container number as the tab name, the excel file builder 
      # blows up due to duplicate sheets named that.
      container_groups(shipment.containers).each_pair do |container_number, containers|
        sheet = new_sheet(builder, container_number)
        add_content_to_sheet(builder, sheet, user, shipment, containers)
        builder.set_column_widths(sheet, *column_widths) unless sheet.nil?
        builder.set_page_setup(sheet, orientation: :landscape, fit_to_width_pages: 1, margins: {left: 0.5, right: 0.5})
      end
    else
      sheet = new_sheet(builder, "Details")
      add_content_to_sheet(builder, sheet, user, shipment, nil)
      builder.set_column_widths(sheet, *column_widths) unless sheet.nil?
      builder.set_page_setup(sheet, orientation: :landscape, fit_to_width_pages: 1, margins: {left: 0.5, right: 0.5})
    end

    builder
  end

  private

  def container_groups containers
    container_groups = Hash.new do |h, k|
      h[k] = []
    end

    containers.each {|c| container_groups[c.container_number] << c }
    container_groups
  end

  def new_sheet(builder, sheet_name)
    builder.create_sheet sheet_name
  end

  def add_content_to_sheet builder, sheet, user, shipment, containers
    containers = Array.wrap(containers)
    add_first_header_rows(builder, sheet, user, shipment, containers.first)
    add_second_header_rows(builder, sheet, user, shipment, containers.first)
    # Add two blank rows
    2.times { add_row builder, sheet, [] }

    lines = containers.length == 0 ? shipment.shipment_lines : containers.map {|c| c.shipment_lines}.flatten

    if lines.length > 0
      rolled_up_lines = roll_up(shipment, user, lines)
      add_lines_to_sheet(builder, sheet, rolled_up_lines) if rolled_up_lines.count > 0
    end

    nil
  end

  def add_first_header_rows(builder, sheet, user, shipment, container)
    fields_to_add = [
      :shp_receipt_location,
      :shp_dest_port_name,
      :shp_final_dest_port_name,
      :shp_master_bill_of_lading,
      :shp_house_bill_of_lading,
      :shp_vessel,
      :shp_voyage
    ]

    container_fields = container.nil? ? [] : [:con_container_number, :con_container_size, :con_seal_number]

    header_labels = (fields_to_add + container_fields + [:shp_importer_reference]).map { |uid| field_label(uid) }
    add_header_row(builder, sheet, header_labels)

    # Generate the data for the shipment / container into the row
    header_values = fields_to_add.map { |uid| field_value(uid, shipment, user) }
    container_fields.each {|uid| header_values << field_value(uid, container, user) }
    header_values << field_value(:shp_importer_reference, shipment, user)

    add_row(builder, sheet, header_values, styles: header_values.map {|v| body_style_text(builder)})
    nil
  end

  def add_second_header_rows(builder, sheet, user, shipment, container)
    fields_to_add = [
        :shp_confirmed_on_board_origin_date,
        :shp_departure_date,
        :shp_eta_last_foreign_port_date,
        :shp_departure_last_foreign_port_date,
        :shp_est_arrival_port_date
    ]

    # The nils below are to make the header row background extend to equal lengths
    headers = fields_to_add.dup
    headers.push nil, nil, nil
    headers.push *[nil, nil, nil] unless container.nil?

    add_header_row(builder, sheet, headers.map { |uid| field_label(uid) })
    add_row(builder, sheet, fields_to_add.map { |uid| field_value(uid, shipment, user) }, styles: fields_to_add.map {|v| body_style_date(builder)} )
    nil
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
                         format_str(ord[:freight_terms]), format_str(ord[:shipment_type]), ord[:first_exp_del].min, ord[:booking_rec].max, 
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

  def line_fields
    [
      :con_container_number,
      :ord_cust_ord_no,
      [cdefs[:prod_part_number], unique_identifier_lambda],
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

  def add_lines_to_sheet(builder, sheet, lines)
    add_header_row(builder, sheet, line_fields.map {|f| field_label(f) })
    lines.each { |line| add_body_row(builder, sheet, line) }
    add_totals_to_sheet(builder, sheet, lines)
  end

  def add_line_to_hsh(shipment, user, line, out_hsh)
    order = line.order_line&.order
    product = line.order_line&.product

    cust_ord_num = field_value(line_fields[1], order, user)
    values = [
      field_value(line_fields[0], line.container, user),
      cust_ord_num,
      field_value(line_fields[2], product, user),
      order&.vendor.name,
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

  def add_totals_to_sheet(builder, sheet, lines)
    carton_qty_total = lines.compact.sum {|line| line[4] || 0}
    pieces_total = lines.compact.sum {|line| line[5] || BigDecimal("0")}
    cbms_total = lines.compact.sum {|line| line[6] || BigDecimal("0")}

    totals_style = body_style_totals(builder)
    add_row(builder, sheet, [nil, nil, nil, "Totals:", carton_qty_total, pieces_total, cbms_total], styles: [nil, nil, nil, totals_style, totals_style, totals_style, totals_style])
  end

  def add_header_row(builder, sheet, data)
    h_style = header_style(builder)
    add_row(builder, sheet, data, styles: data.map {|v| h_style })
  end

  def add_body_row(builder, sheet, data)
    t_style = body_style_text(builder)
    d_style = body_style_date(builder)
    n_style = body_style_numeric(builder)
    styles = [t_style, t_style, t_style, t_style, n_style, n_style, n_style, d_style, t_style, t_style, d_style, d_style, d_style, d_style, t_style, t_style]
    add_row(builder, sheet, data, styles: styles)
  end

  def add_row(builder, sheet, data, styles: [])
    builder.add_body_row sheet, data, styles: styles
  end

  def header_style builder
    builder.create_style(:jjill_header, {bg_color:XlsxBuilder::HEADER_BG_COLOR_HEX, fg_color: "000000", b: true, alignment: {horizontal: :center, vertical: :bottom, wrap_text: true}}, return_existing: true)
  end

  def body_style_text builder
    builder.create_style(:jjill_text, {alignment: {horizontal: :center, vertical: :center, wrap_text: true}}, return_existing: true)
  end

  def body_style_date builder
    builder.create_style(:jjill_date, {format_code: "YYYY-MM-DD", alignment: {horizontal: :center, vertical: :center, wrap_text: true}}, return_existing: true)
  end

  def body_style_totals builder
    builder.create_style(:jjill_totals, {format_code: "#,##0.####", alignment: {horizontal: :center, vertical: :center, wrap_text: true}, border: {style: :thin, color: "000000", edges: [:top]}, b: true}, return_existing: true)
  end

  def body_style_numeric builder
    builder.create_style(:jjill_number, {format_code: "#,##0.####", alignment: {horizontal: :right, vertical: :center, wrap_text: true}}, return_existing: true)
  end

  def column_widths
    [15, 13, 45, 30, 20, 18, 15, 14, 10, 14, 13, 12, 13, 12, 8, 13]
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

  def field_label field
    return nil if field.nil?

    # Always just use the first model field value given
    f = field.respond_to?(:first) ? field.first : field

    # JILL wants to see some diffrent labels, since this report was copied from another system
    overrides = {shp_fish_and_wildlife: "Fish & Wildlife Flag", ord_ship_to_system_code: "Warehouse Code", con_container_size: "Container Size", shp_importer_reference: "K File #"}
    overrides[f] || mf(f).label(false)
  end

  def mf field
    return nil if field.nil?

    field.respond_to?(:model_field) ? field.model_field : ModelField.find_by_uid(field)
  end

  def cdefs 
    @cdefs ||= self.class.prep_custom_definitions [:prod_part_number]
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
