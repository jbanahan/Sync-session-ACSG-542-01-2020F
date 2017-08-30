require 'open_chain/custom_handler/isf_xml_generator'
require 'open_chain/order_booking_registry'

module Api; module V1; class ShipmentsController < Api::V1::ApiCoreModuleControllerBase
  include ActionView::Helpers::NumberHelper

  def initialize
    super(OpenChain::Api::ApiEntityJsonizer.new(force_big_decimal_numeric:true, blank_if_nil:true))
  end

  def core_module
    CoreModule::SHIPMENT
  end

  def create_booking_from_order
    lines, order = make_booking_lines_for_order(params[:order_id])
    h = {
      shp_ref: Shipment.generate_reference,
      shp_imp_id: order.importer_id,
      shp_ven_id: order.vendor_id,
      shp_ship_from_id: order.ship_from_id,
      booking_lines: lines
    }
    OpenChain::OrderBookingRegistry.registered.each {|r| r.book_from_order_hook(h,order,lines)}
    params['shipment'] = h.with_indifferent_access
    do_create core_module
  end

  def book_order
    lines, order = make_booking_lines_for_order(params[:order_id])
    s = Shipment.find params[:id]
    raise StatusableError.new('Order and shipment importer must match.',400) unless s.importer == order.importer
    raise StatusableError.new('Order and shipment vendor must match.',400) unless s.vendor == order.vendor
    raise StatusableError.new('Order and shipment must have same ship from address.',400) unless s.ship_from = order.ship_from
    h = {
      id: s.id,
      booking_lines: lines
    }
    OpenChain::OrderBookingRegistry.registered.each {|r| r.book_from_order_hook(h,order,lines)}
    params['shipment'] = h.with_indifferent_access
    do_update core_module
  end

  def available_orders
    s = get_shipment
    ord_fields = [:ord_ord_num,:ord_cust_ord_no,:ord_mode,:ord_imp_name,:ord_ord_date,:ord_ven_name]
    r = []
    s.available_orders(current_user).order('customer_order_number').limit(25).each do |ord|
      hsh = {id:ord.id}
      ord_fields.each {|uid| hsh[uid] = export_field(uid, ord)}
      r << hsh
    end
    render json: {available_orders:r}
  end

  def booked_orders
    s = get_shipment
    ord_fields = [:ord_ord_num,:ord_cust_ord_no]
    result = []
    lines_available = s.booking_lines.where('order_line_id IS NOT NULL').any?
    order_ids = s.booking_lines.where('order_id IS NOT NULL').uniq.pluck(:order_id) # select distinct order_id from booking_lines where...
    Order.where(id: order_ids).each do |order|
      hsh = {id:order.id}
      ord_fields.each {|uid| hsh[uid] = export_field(uid, order)}
      result << hsh
    end
    render json: {booked_orders:result, lines_available: lines_available}
  end

  def available_lines # makes a fake order based on booking lines.
    s = get_shipment
    lines = s.booking_lines.where('order_line_id IS NOT NULL').map do |line|
      {id: line.order_line_id,
       ordln_line_number: line.line_number,
       ordln_puid: line.product_identifier,
       ordln_sku: line.order_line.sku,
       ordln_ordered_qty: line.quantity,
       linked_line_number: line.order_line.line_number,
       linked_cust_ord_no: line.customer_order_number}
    end
    render json: {lines: lines}
  end

  def open_bookings
    # If we're looking for bookings for a specific order then the order_id should be sent, otherwise, if it's not we'll limit the bookings
    # based on the user's linked companies.
    order = params["order_id"].present? ? Order.where(id: params["order_id"].to_i).first : nil

    shipments = Shipment.search_secure current_user, Shipment.scoped
    if order
      if order.can_view?(current_user)
        shipments = shipments.where(vendor_id: order.vendor_id, importer_id: order.importer_id)
      else
        shipments = shipments.where("1 = 0")
      end
    elsif current_user.company.vendor?
      shipments = shipments.where(vendor_id: current_user.company_id)
    elsif current_user.company.importer?
      shipments = shipments.where(importer_id: current_user.company_id)
    else
      shipments = shipments.where(importer_id: current_user.company.linked_companies.where(importer: true).pluck(:id))
    end

    registry = OpenChain::OrderBookingRegistry.registered
    if registry.length > 0
      OpenChain::OrderBookingRegistry.registered.each {|r| shipments = r.open_bookings_hook(current_user, shipments, order)}
    else
      # By default, drop off any bookings where shipment instructions have been sent to the carrier
      shipments = shipments.where(shipment_instructions_sent_date: nil)
    end

    render json: {results: shipments.order("updated_at DESC").limit(200).map {|s| obj_to_json_hash(s) }}
  end

  def process_tradecard_pack_manifest
    attachment_job('Tradecard Pack Manifest')
  end

  def process_booking_worksheet
    attachment_job('Booking Worksheet')
  end

  def process_manifest_worksheet
    attachment_job('Manifest Worksheet')
  end

  def request_booking
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have permission to request a booking.",:forbidden) unless s.can_request_booking?(current_user)
    s.async_request_booking! current_user
    render json: {'ok'=>'ok'}
  end

  def approve_booking
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have permission to approve a booking.",:forbidden) unless s.can_approve_booking?(current_user)
    s.async_approve_booking! current_user
    render json: {'ok'=>'ok'}
  end

  def confirm_booking
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have permission to confirm a booking.",:forbidden) unless s.can_confirm_booking?(current_user)
    s.async_confirm_booking! current_user
    render json: {'ok'=>'ok'}
  end

  def revise_booking
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have permission to revise this booking.",:forbidden) unless s.can_revise_booking?(current_user)
    s.async_revise_booking! current_user
    render json: {'ok'=>'ok'}
  end

  def request_cancel
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have permission to request a booking.",:forbidden) unless s.can_request_cancel?(current_user)
    s.async_request_cancel! current_user
    render json: {'ok'=>'ok'}
  end

  def cancel
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have permission to cancel this booking.",:forbidden) unless s.can_cancel?(current_user)
    s.async_cancel_shipment! current_user
    render json: {'ok'=>'ok'}
  end

  def uncancel
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have permission to undo canceling this booking.",:forbidden) unless s.can_uncancel?(current_user)
    s.async_uncancel_shipment! current_user
    render json: {'ok'=>'ok'}
  end

  def send_shipment_instructions
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have to send shipment instructions.",:forbidden) unless s.can_send_shipment_instructions?(current_user)
    s.async_send_shipment_instructions! current_user
    render json: {'ok'=>'ok'}
  end

  def send_isf
    shipment = Shipment.find params[:id]
    if shipment.valid_isf?
      ISFXMLGenerator.delay.generate_and_send(shipment.id, !shipment.isf_sent_at)
      shipment.mark_isf_sent!(current_user)
    else
      raise 'Invalid ISF! <ul><li>' + shipment.errors.full_messages.join('</li><li>') + '</li></ul>'
    end
  end

  def save_object h
    shp = h['id'].blank? ? Shipment.new : Shipment.includes([
      {shipment_lines: [:piece_sets,{custom_values:[:custom_definition]},:product]},
      {booking_lines: [:order_line, :product]},
      :containers,
      {custom_values:[:custom_definition]}
    ]).find_by_id(h['id'])
    raise StatusableError.new("Object with id #{h['id']} not found.",404) if shp.nil?
    shp = freeze_custom_values shp, false #don't include order fields
    import_fields h, shp, CoreModule::SHIPMENT
    load_containers shp, h
    load_carton_sets shp, h
    load_lines shp, h
    load_booking_lines shp, h
    raise StatusableError.new("You do not have permission to save this Shipment.",:forbidden) unless shp.can_edit?(current_user)
    shp.save if shp.errors.full_messages.blank?
    shp

  end
  def obj_to_json_hash s
    headers_to_render = limit_fields([
      :shp_arrival_port_date,
      :shp_booked_order_ids,
      :shp_booked_orders,
      :shp_booked_quantity,
      :shp_booking_approved_by_full_name,
      :shp_booking_approved_date,
      :shp_booking_cargo_ready_date,
      :shp_booking_carrier,
      :shp_booking_confirmed_by_full_name,
      :shp_booking_confirmed_date,
      :shp_booking_cutoff_date,
      :shp_booking_est_arrival_date,
      :shp_booking_est_departure_date,
      :shp_booking_first_port_receipt_name,
      :shp_booking_mode,
      :shp_booking_number,
      :shp_booking_received_date,
      :shp_booking_request_count,
      :shp_booking_requested_by_full_name,
      :shp_booking_requested_equipment,
      :shp_booking_revised_by_full_name,
      :shp_booking_revised_date,
      :shp_booking_shipment_type,
      :shp_booking_vessel,
      :shp_buyer_address_full_address,
      :shp_buyer_address_id,
      :shp_buyer_address_name,
      :shp_cancel_requested_at,
      :shp_cancel_requested_by_full_name,
      :shp_canceled_by_full_name,
      :shp_canceled_date,
      :shp_car_name,
      :shp_car_syscode,
      :shp_cargo_on_hand_date,
      :shp_cargo_ready_date,
      :shp_chargeable_weight,
      :shp_comment_count,
      :shp_confirmed_on_board_origin_date,
      :shp_consolidator_address_full_address,
      :shp_consolidator_address_id,
      :shp_consolidator_address_name,
      :shp_container_stuffing_address_full_address,
      :shp_container_stuffing_address_id,
      :shp_container_stuffing_address_name,
      :shp_cutoff_date,
      :shp_delay_reason_codes,
      :shp_delivered_date,
      :shp_departure_date,
      :shp_departure_last_foreign_port_date,
      :shp_dest_port_id,
      :shp_dest_port_name,
      :shp_dimensional_weight,
      :shp_do_issued_at,
      :shp_docs_received_date,
      :shp_est_arrival_port_date,
      :shp_est_delivery_date,
      :shp_est_departure_date,
      :shp_est_inland_port_date,
      :shp_est_load_date,
      :shp_eta_last_foreign_port_date,
      :shp_export_license_required,
      :shp_final_dest_port_id,
      :shp_final_dest_port_name,
      :shp_first_port_receipt_id,
      :shp_first_port_receipt_name,
      :shp_fish_and_wildlife,
      :shp_freight_terms,
      :shp_freight_total,
      :shp_fwd_id,
      :shp_fwd_name,
      :shp_fwd_syscode,
      :shp_gross_weight,
      :shp_hazmat,
      :shp_house_bill_of_lading,
      :shp_imp_id,
      :shp_imp_name,
      :shp_imp_syscode,
      :shp_importer_reference,
      :shp_in_warehouse_time,
      :shp_inland_dest_port,
      :shp_inland_dest_port_id,
      :shp_inland_dest_port_name,
      :shp_inland_port_date,
      :shp_invoice_total,
      :shp_isf_sent_at,
      :shp_lacey,
      :shp_lading_port_id,
      :shp_lading_port_name,
      :shp_last_foreign_port_id,
      :shp_last_foreign_port_name,
      :shp_lcl,
      :shp_manufacturer_address_full_address,
      :shp_manufacturer_address_name,
      :shp_marks_and_numbers,
      :shp_master_bill_of_lading,
      :shp_mode,
      :shp_number_of_packages,
      :shp_number_of_packages_uom,
      :shp_pickup_at,
      :shp_port_last_free_day,
      :shp_receipt_location,
      :shp_ref,
      :shp_requested_equipment,
      :shp_seller_address_full_address,
      :shp_seller_address_id,
      :shp_seller_address_name,
      :shp_ship_from_id,
      :shp_ship_from_name,
      :shp_ship_from_full_address,
      :shp_ship_to_full_address,
      :shp_ship_to_id,
      :shp_ship_to_name,
      :shp_shipment_instructions_sent_date,
      :shp_shipment_instructions_sent_by_full_name,
      :shp_shipment_type,
      :shp_swpm,
      :shp_trucker_name,
      :shp_unlading_port_id,
      :shp_unlading_port_name,
      :shp_ven_id,
      :shp_ven_syscode,
      :shp_vessel,
      :shp_vessel_carrier_scac,
      :shp_vessel_nationality,
      :shp_volume,
      :shp_voyage
    ] + custom_field_keys(CoreModule::SHIPMENT))

    container_fields_to_render = ([
      :con_uid,
      :con_container_number,
      :con_container_size,
      :con_size_description,
      :con_weight,
      :con_seal_number,
      :con_teus,
      :con_fcl_lcl,
      :con_quantity,
      :con_uom,
      :con_shipment_line_count
    ] + custom_field_keys(CoreModule::CONTAINER))

    h = {id: s.id}
    headers_to_render.each {|uid| h[uid] = export_field(uid, s)}
    if render_shipment_lines?
      h['lines'] = render_lines(preload_shipment_lines(s, render_order_fields?, true), shipment_line_fields_to_render, render_order_fields?)
    end
    if render_booking_lines?
      h['booking_lines'] = render_lines(preload_booking_lines(s), booking_line_fields_to_render)
    end

    h['containers'] = render_lines(s.containers, container_fields_to_render) if s.containers.any?

    if render_carton_sets?
      h['carton_sets'] = render_carton_sets(s)
    end
    if render_attachments?
      render_attachments(s,h)
    end
    if render_summary?
      h['summary'] = render_summary(s)
    end
    if render_comments?
      h['comments'] = render_comments(s, current_user)
    end
    h['permissions'] = render_permissions(s)
    custom_view = OpenChain::CustomHandler::CustomViewSelector.shipment_view(s,current_user)
    if !custom_view.blank?
      h['custom_view'] = custom_view
    end
    h
  end

  def preload_shipment_lines shipment, render_order_fields, custom_values
    if render_order_fields?
      if custom_values
        return shipment.shipment_lines.includes([{piece_sets: {order_line: [:order]}}, :custom_values, {product: [:custom_values]}])
      else
        return shipment.shipment_lines.includes([{piece_sets: {order_line: [:order]}}, {product: [:custom_values]}])
      end
      
    else
      return shipment.shipment_lines
    end
  end

  def preload_booking_lines shipment
    shipment.booking_lines.includes([{order_line: [:order]}, :order])
  end

  def shipment_lines
    s = get_shipment
    h = {id: s.id}
  
    h['lines'] = render_lines(preload_shipment_lines(s, render_order_fields?, true), shipment_line_fields_to_render, render_order_fields?)

    render json: {'shipment' => h}
  end

  def booking_lines
    s = get_shipment
    h = {id: s.id}
    h['booking_lines'] = render_lines(preload_booking_lines(s), booking_line_fields_to_render)

    render json: {'shipment' => h}
  end

  #override api_controller method to pre-load lines
  def find_object_by_id id
    includes_array = [
      {shipment_lines: [:piece_sets,:custom_values,:product]},
      :containers,
      :custom_values
    ]
    includes_array[0][:shipment_lines][0] = {piece_sets: {order_line: [:custom_values, :product, :order]}} if render_order_fields?
    s = Shipment.where(id:id).includes(includes_array).first
    s = freeze_custom_values s, render_order_fields?
    s
  end

  def autocomplete_order
    results = []
    if !params[:n].blank?
      s = get_shipment

      orders = s.available_orders current_user
      results = orders.where('customer_order_number LIKE ? OR order_number LIKE ?',"%#{params[:n]}%", "%#{params[:n]}%").
                  limit(10).
                  collect {|order|
                    # Use whatever field matched as the title that's getting returned
                    title = (order.customer_order_number.to_s.upcase.include?(params[:n].to_s.upcase) ? order.customer_order_number : order.order_number)
                    {order_number:(title), id:order.id}
                  }
    end

    render json: results
  end

  def autocomplete_product
    results = []
    if !params[:n].blank?
      s = get_shipment

      products = s.available_products current_user
      results = products.where("unique_identifier LIKE ? ", "%#{params[:n]}%").
                  limit(10).
                  collect {|product| { unique_identifier:product.unique_identifier, id:product.id }}
    end

    render json: results
  end

  def autocomplete_address
    json = []
    if !params[:n].blank?
      s = get_shipment

      result = Address.where('addresses.name like ?',"%#{params[:n]}%").where(in_address_book:true).joins(:company).where(Company.secure_search(current_user)).where(companies: {id: s.importer_id})
      result = result.order(:name)
      result = result.limit(10)
      json = result.map {|address| {name:address.name, full_address:address.full_address, id:address.id} }
    end

    render json: json
  end

  def create_address
    s = get_shipment

    address = Address.new params[:address]
    address.company = s.importer

    address.save!

    render json: address
  end

  private
  def get_shipment
    s = Shipment.find params[:id]
    raise StatusableError.new("Shipment not found.",404) unless s.can_view?(current_user)
    s
  end

  def booking_line_fields_to_render
    limit_fields([
      :bkln_line_number,
      :bkln_quantity,
      :bkln_puid,
      :bkln_carton_qty,
      :bkln_gross_kgs,
      :bkln_cbms,
      :bkln_carton_set_id,
      :bkln_order_and_line_number,
      :bkln_order_id,
      :bkln_container_size,
      :bkln_var_db_id,
      :bkln_varuid,
      :bkln_order_line_id,
      :bkln_product_db_id
     ])
  end

  def shipment_line_fields_to_render
    limit_fields([
      :shpln_line_number,
      :shpln_shipped_qty,
      :shpln_puid,
      :shpln_pname,
      :shpln_container_uid,
      :shpln_container_number,
      :shpln_container_size,
      :shpln_cbms,
      :shpln_gross_kgs,
      :shpln_carton_qty,
      :shpln_carton_set_uid,
      :shpln_manufacturer_address_name,
      :shpln_manufacturer_address_full_address,
      :shpln_cust_ord_no
    ] + custom_field_keys(CoreModule::SHIPMENT_LINE))
  end

  def render_permissions shipment
    {
      can_edit:shipment.can_edit?(current_user),
      can_view:shipment.can_view?(current_user),
      can_attach:shipment.can_attach?(current_user),
      can_comment:shipment.can_comment?(current_user),
      can_book:shipment.can_book?,
      can_request_booking:shipment.can_request_booking?(current_user),
      can_approve_booking:shipment.can_approve_booking?(current_user),
      can_confirm_booking:shipment.can_confirm_booking?(current_user),
      can_revise_booking:shipment.can_revise_booking?(current_user),
      can_edit_booking:shipment.can_edit_booking?(current_user),
      can_add_remove_shipment_lines:shipment.can_add_remove_shipment_lines?(current_user),
      can_add_remove_booking_lines:shipment.can_add_remove_booking_lines?(current_user),
      can_request_cancel:shipment.can_request_cancel?(current_user),
      can_cancel:shipment.can_cancel?(current_user),
      can_uncancel:shipment.can_uncancel?(current_user),
      can_send_isf:shipment.can_approve_booking?(current_user, true),
      enabled_booking_types:shipment.enabled_booking_types,
      can_send_shipment_instructions:shipment.can_send_shipment_instructions?(current_user)
    }
  end
  def render_shipment_lines?
    params[:shipment_lines].present? || action_name == 'create'
  end
  def render_booking_lines?
    params[:booking_lines].present? || action_name == 'create'
  end
  def render_lines (lines, fields_to_render, with_order_lines=false)
    lines.map do |sl|
      rendered_line = {id: sl.id}
      fields_to_render.each {|uid| rendered_line[uid] = export_field(uid, sl)}
      rendered_line['order_lines'] = render_order_fields(sl) if with_order_lines
      rendered_line
    end
  end
  def render_carton_sets?
    params[:include] && params[:include].match(/carton_sets/)
  end
  def render_carton_sets shipment
    fields = limit_fields([
      :cs_starting_carton,
      :cs_carton_qty,
      :cs_length,
      :cs_width,
      :cs_height,
      :cs_net_net,
      :cs_net,
      :cs_gross
    ])
    render_lines(shipment.carton_sets, fields)
  end
  def render_summary?
    params[:summary]
  end
  def render_summary shipment
    booked_piece_count = 0
    piece_count = 0
    booked_order_ids = Set.new
    order_ids = Set.new
    booked_product_ids = Set.new
    product_ids = Set.new
    line_count = 0
    booking_line_count = 0

    # This query runs WAY faster than iterating over the shipment lines, piece sets, order lines to get counts.
    ActiveRecord::Base.connection.execute("select ol.id, ol.order_id, ol.product_id, l.quantity FROM shipment_lines l
      inner join piece_sets p on l.id = p.shipment_line_id
      inner join order_lines ol on p.order_line_id = ol.id
      where l.shipment_id = #{shipment.id}").each do |row|

      order_ids << row[1] unless row[1].nil?
      product_ids << row[2] unless row[2].nil?
      line_count += 1
      piece_count += row[3] unless row[3].nil?
    end

    preload_booking_lines(shipment).each do |bl|
      booking_line_count += 1
      booked_piece_count += bl.quantity unless bl.quantity.nil?
      if bl.order_line_id.present?
        booked_order_ids << bl.order_line.order_id
      else
        booked_order_ids << bl.order_id if bl.order_id.present?
      end
      booked_product_ids << bl.product_id if bl.product_id.present?
    end
    {
      line_count: number_with_delimiter(line_count),
      booked_line_count: number_with_delimiter(booking_line_count),
      piece_count: number_with_delimiter(number_with_precision(piece_count, strip_insignificant_zeros:true)),
      booked_piece_count: number_with_delimiter(number_with_precision(booked_piece_count, strip_insignificant_zeros:true)),
      order_count: number_with_delimiter(order_ids.size),
      booked_order_count: number_with_delimiter(booked_order_ids.size),
      product_count: number_with_delimiter(product_ids.size),
      booked_product_count: number_with_delimiter(booked_product_ids.to_a.compact.length)
    }
  end
  def render_order_fields?
    params[:include] && params[:include].match(/order_lines/)
  end
  #return hash with extra order line fields
  def render_order_fields shipment_line
    shipment_line.piece_sets.collect do |ps|
      if ps.order_line_id
        ol = ps.order_line
        order = ol.order
        olh = {'allocated_quantity'=>ps.quantity,
          'order_id'=>order.id,
          'ord_ord_num'=>export_field(:ord_ord_num,order),
          'ord_cust_ord_no'=>export_field(:ord_cust_ord_no,order),
          'id'=>ol.id
        }
        line_fields = limit_fields([
          :ordln_line_number,
          :ordln_puid,
          :ordln_pname,
          :ordln_ppu,
          :ordln_currency,
          :ordln_ordered_qty,
          :ordln_country_of_origin,
          :ordln_hts
        ])
        line_fields.each {|uid| olh[uid] = export_field(uid, ol)}
        olh
      else
        nil
      end
    end
  end
  def load_lines shipment, h
    if h['lines']
      h['lines'].each_with_index do |base_ln,i|
        ln = base_ln.clone
        if !ln['shpln_puid'].blank? && !ln['shpln_pname'].blank?
          ln.delete 'shpln_pname' #dont' need to update for both
        end
        s_line = shipment.shipment_lines.find {|obj| match_numbers?(ln['id'], obj.id) || match_numbers?(ln['shpln_line_number'], obj.line_number)}
        if s_line.nil?
          raise StatusableError.new("You cannot add lines to this shipment.",400) unless shipment.can_add_remove_shipment_lines?(current_user)
          s_line = shipment.shipment_lines.build(line_number:ln['cil_line_number'])
        end
        if ln['_destroy']
          raise StatusableError.new("You cannot remove lines from this shipment.",400) unless shipment.can_add_remove_shipment_lines?(current_user)
          s_line.mark_for_destruction
          next
        end
        import_fields ln, s_line, CoreModule::SHIPMENT_LINE
        if ln['linked_order_line_id']
          o_line = OrderLine.find_by_id ln['linked_order_line_id']
          shipment.errors[:base] << "Order line #{ln['linked_order_line_id']} not found." unless o_line && o_line.can_view?(current_user)
          s_line.product = o_line.product if s_line.product.nil?
          shipment.errors[:base] << "Order line #{o_line.id} does not have the same product as the shipment line provided (#{s_line.product.unique_identifier})" unless s_line.product == o_line.product
          s_line.linked_order_line_id = ln['linked_order_line_id']
        end
        shipment.errors[:base] << "Product required for shipment lines." unless s_line.product
        shipment.errors[:base] << "Product not found." if s_line.product && !s_line.product.can_view?(current_user)
      end
    end
  end

  def load_booking_lines(shipment, h)
    if h['booking_lines']
      h['booking_lines'].each_with_index do |base_ln,i|
        ln = base_ln.clone
        s_line = shipment.booking_lines.find {|obj| match_numbers?(ln['id'], obj.id) || match_numbers?(ln['bkln_line_number'], obj.line_number)}
        if s_line.nil?
          raise StatusableError.new("You cannot add lines to this shipment.",400) unless shipment.can_add_remove_booking_lines?(current_user)
          max_line_number = shipment.booking_lines.maximum(:line_number) || 0
          s_line = shipment.booking_lines.build(line_number:max_line_number+(i+1))
        end
        if ln['_destroy']
          raise StatusableError.new("You cannot remove lines from this shipment.",400) unless shipment.can_add_remove_booking_lines?(current_user)
          s_line.mark_for_destruction
          next
        end
        s_line.order_line_id = ln['bkln_order_line_id'] if ln['bkln_order_line_id']
        # If the data has a order line id, blank out the order id and product id values.  The order line should always provide order and product data for the booking line.
        # If order line id is set and order or product ids are present a validation will also fail and the save will rollback.
        if !s_line.order_line_id.blank?
          s_line.order_id = nil
          s_line.product_id = nil
          ln['bkln_order_id'] = nil
          ln['bkln_product_id'] = nil
        end
        import_fields ln, s_line, CoreModule::BOOKING_LINE
      end
    end
  end


  def load_containers shipment, h
    update_collection('containers', shipment, h, CoreModule::CONTAINER)
  end

  def load_carton_sets shipment, h
    update_collection('carton_sets', shipment, h, CoreModule::CARTON_SET)
  end

  def update_collection(collection_name, shipment, h, core_module)
    if h[collection_name]
      collection = h[collection_name]
      collection.each do |ln|
        cs = shipment.send(collection_name).find { |obj| match_numbers? ln['id'], obj.id }
        cs = shipment.send(collection_name).build if cs.nil?
        if ln['_destroy']
          if all_shipment_lines_will_be_deleted?(cs.shipment_lines,h['lines'])
            cs.mark_for_destruction
            next
          else
            shipment.errors[:base] << "Cannot delete #{collection_name} linked to shipment lines."
          end
        end
        import_fields ln, cs, core_module
      end
    end
  end
  
  def all_shipment_lines_will_be_deleted? line_collection, line_array
    line_collection.each do |ln|
      l_a = line_array ? line_array : []
      ln_hash = l_a.find {|lh| lh['id'].to_s == ln.id.to_s}
      
      # if the hash has the _destroy then keep going to the next line
      next if ln_hash && ln_hash['_destroy']
      
      # didn't find a _destroy for this line, so fail
      return false
    end
  end
  

  def match_numbers? hash_val, number
    hash_val.present? && hash_val.to_s == number.to_s
  end

  def freeze_custom_values s, include_order_lines
    #force the internal cache of custom values for so the
    #get_custom_value methods don't double check the DB for missing custom values
    if s
      s.freeze_custom_values
      s.shipment_lines.each {|sl|
        sl.freeze_custom_values
        if sl.product
          sl.product.freeze_custom_values
        end

        if include_order_lines
          sl.piece_sets.each {|ps|
            ol = ps.order_line
            if ol
              ol.freeze_custom_values
              if ol.product
                ol.product.freeze_custom_values
              end
            end
          }
        end
      }
    end
    s
  end

  def attachment_job(job_name)
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have permission to edit this Shipment.",:forbidden) unless s.can_edit?(current_user)
    att = s.attachments.find_by_id(params[:attachment_id])
    raise StatusableError.new("Attachment not linked to Shipment.", 400) unless att
    aj = s.attachment_process_jobs.where(attachment_id:att.id,
                                         job_name: job_name).first_or_create!(user_id:current_user.id)
    if aj.start_at
      raise StatusableError.new("This manifest has already been submitted for processing.",400)
    else
      aj.update_attributes(start_at:Time.now)
      if ['Tradecard Pack Manifest', 'Manifest Worksheet'].include? job_name
        aj.process manufacturer_address_id: params[:manufacturer_address_id]
      else
        aj.process
      end
      render_show CoreModule::SHIPMENT
    end
  end

  def render_comments?
    params[:include].present? && params[:include].match(/comments/)
  end

  def render_comments s, user
    s.comments.map {|c| c.comment_json(user) }
  end

  def make_booking_lines_for_order order_id
    o = Order.includes(:order_lines).where(id:order_id).first
    raise StatusableError.new("Order not found",404) unless o.can_view?(current_user)
    raise StatusableError.new("You do not have permission to book this order.",403) unless o.can_book?(current_user)
    lines = []
    o.order_lines.each do |ol|
      bl = HashWithIndifferentAccess.new
      bl[:bkln_order_line_id] = ol.id
      bl[:bkln_quantity] = ol.quantity
      bl[:bkln_var_db_id] = ol.variant_id
      lines << bl
    end
    [lines, o]
  end
end; end; end
