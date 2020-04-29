require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; class ShipmentDownloadGenerator
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def generate builder, shipment, user
    mode = shipment.mode.presence || shipment.booking_mode.presence
    if mode.to_s.upcase != "AIR" && shipment.containers.length > 0
      preload_shipment(shipment, lines_through_containers: true)

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
      preload_shipment(shipment, lines_through_containers: false)
      sheet = new_sheet(builder, "Details")
      add_content_to_sheet(builder, sheet, user, shipment, nil)
      builder.set_column_widths(sheet, *column_widths) unless sheet.nil?
      builder.set_page_setup(sheet, orientation: :landscape, fit_to_width_pages: 1, margins: {left: 0.5, right: 0.5})
    end

    builder
  end

  private

  def preload_shipment shipment, lines_through_containers: false
    shipment_lines_association = {
      shipment_lines: [:container, {order_lines: [order: [:vendor], product: [:custom_values]]}]
    }

    if lines_through_containers
      shipment_lines_association = {containers: shipment_lines_association}
    end

     ActiveRecord::Associations::Preloader.new.preload(shipment, shipment_lines_association)
  end

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

    add_lines_to_sheet(builder, sheet, user, shipment, lines) if lines.length > 0
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

    header_labels = (fields_to_add + container_fields).map { |uid| field_label(uid) }
    add_header_row(builder, sheet, header_labels)

    # Generate the data for the shipment / container into the row
    header_values = fields_to_add.map { |uid| field_value(uid, shipment, user) }
    container_fields.each {|uid| header_values << field_value(uid, container, user) }

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
    headers.push nil, nil
    headers.push *[nil, nil, nil] unless container.nil?

    add_header_row(builder, sheet, headers.map { |uid| field_label(uid) })
    add_row(builder, sheet, fields_to_add.map { |uid| field_value(uid, shipment, user) }, styles: fields_to_add.map {|v| body_style_date(builder)} )
    nil
  end

  def add_lines_to_sheet(builder, sheet, user, shipment, lines)
    fields = [
      :con_container_number,
      :ord_cust_ord_no,
      cdefs[:prod_part_number],
      :ord_ven_name,
      :shpln_carton_qty,
      :shpln_shipped_qty,
      :shpln_cbms,
      "Chargeable Weight (KGS)",
      :shpln_gross_kgs,
      :ord_window_end,
      :shp_freight_terms,
      :shp_shipment_type,
      :ord_first_exp_del,
      :shp_booking_received_date,
      :shp_cargo_on_hand_date,
      :shp_docs_received_date
    ]

    add_header_row(builder, sheet, fields.map {|f| field_label(f) })
    lines.each { |line| add_line_to_sheet(builder, sheet, user, shipment, line, fields) }
    add_totals_to_sheet(builder, sheet, lines)
    nil
  end

  def add_line_to_sheet(builder, sheet, user, shipment, line, fields)
    order_line = line.order_line
    order = order_line&.order
    product = order_line&.product

    values = [
      field_value(fields[0], line.container, user),
      field_value(fields[1], order, user),
      field_value(fields[2], product, user),
      field_value(fields[3], order, user),
      field_value(fields[4], line, user),
      field_value(fields[5], line, user),
      field_value(fields[6], line, user),
      line.chargeable_weight,
      field_value(fields[8], line, user),
      field_value(fields[9], order, user),
      field_value(fields[10], shipment, user),
      field_value(fields[11], shipment, user),
      field_value(fields[12], order, user),
      field_value(fields[13], shipment, user),
      field_value(fields[14], shipment, user),
      field_value(fields[15], shipment, user)
    ]

    add_body_row(builder, sheet, values)
  end

  def add_totals_to_sheet(builder, sheet, lines)
    carton_qty_total = 0
    pieces_total = BigDecimal("0")
    cbms_total = BigDecimal("0")
    chargeable_weight_total = BigDecimal("0")
    gross_weight_total = BigDecimal("0")

    lines.each do |line|
      carton_qty_total += (line.carton_qty || 0)
      pieces_total += (line.quantity || BigDecimal("0"))
      cbms_total += (line.cbms || BigDecimal("0"))
      chargeable_weight_total += (line.chargeable_weight || BigDecimal("0"))
      gross_weight_total += (line.gross_kgs || BigDecimal("0"))
    end


    totals_style = body_style_totals(builder)
    integer_totals_style = body_style_integer_totals(builder)
    add_row(builder, sheet, [nil, nil, nil, "Totals:", carton_qty_total, pieces_total, cbms_total, chargeable_weight_total, gross_weight_total], styles: [nil, nil, nil, totals_style, integer_totals_style, totals_style, totals_style, totals_style, totals_style])
  end

  def add_header_row(builder, sheet, data)
    h_style = header_style(builder)
    add_row(builder, sheet, data, styles: data.map {|v| h_style })
  end

  def add_body_row(builder, sheet, data)
    t_style = body_style_text(builder)
    d_style = body_style_date(builder)
    n_style = body_style_numeric(builder)
    i_style = body_style_integer(builder)
    styles = [t_style, t_style, t_style, t_style, i_style, n_style, n_style, n_style, n_style, d_style, t_style, t_style, d_style, d_style, d_style, d_style]
    add_row(builder, sheet, data, styles: styles)
  end

  def add_row(builder, sheet, data, styles: [])
    builder.add_body_row sheet, data, styles: styles
  end

  def field_value field, object, user
    v = mf(field).process_export object, user
    v = nil if v.blank?
    v
  end

  def field_label field
    return nil if field.nil?

    return field if field.is_a?(String)

    mf(field).label(false)
  end

  def mf field
    return nil if field.nil?

    field.respond_to?(:model_field) ? field.model_field : ModelField.find_by_uid(field)
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [:prod_part_number]
  end

  def header_style builder
    builder.create_style(:ship_header, {bg_color:XlsxBuilder::HEADER_BG_COLOR_HEX, fg_color: "000000", b: true, alignment: {horizontal: :center, vertical: :bottom, wrap_text: true}}, return_existing: true)
  end

  def body_style_text builder
    builder.create_style(:ship_text, {alignment: {horizontal: :center, vertical: :center, wrap_text: true}}, return_existing: true)
  end

  def body_style_date builder
    builder.create_style(:ship_date, {format_code: "YYYY-MM-DD", alignment: {horizontal: :center, vertical: :center, wrap_text: true}}, return_existing: true)
  end

  def body_style_integer_totals builder
    builder.create_style(:ship_totals_integer, {format_code: "#,##0", alignment: {horizontal: :center, vertical: :center, wrap_text: true}, border: {style: :thin, color: "000000", edges: [:top]}, b: true}, return_existing: true)
  end

  def body_style_totals builder
    builder.create_style(:ship_totals, {format_code: "#,##0.00##", alignment: {horizontal: :center, vertical: :center, wrap_text: true}, border: {style: :thin, color: "000000", edges: [:top]}, b: true}, return_existing: true)
  end

  def body_style_integer builder
    builder.create_style(:ship_integer, {format_code: "#,##0", alignment: {horizontal: :right, vertical: :center, wrap_text: true}}, return_existing: true)
  end

  def body_style_numeric builder
    builder.create_style(:ship_number, {format_code: "#,##0.00##", alignment: {horizontal: :right, vertical: :center, wrap_text: true}}, return_existing: true)
  end

  def column_widths
    [15, 15, 25, 27, 15, 15, 10, 13, 11, 13, 13, 12, 13, 13, 13, 13]
  end

end; end; end
