require 'open_chain/api/api_entity_jsonizer'
require 'open_chain/api/v1/api_json_controller_adapter'
require 'open_chain/api/v1/order_api_json_generator'
require 'open_chain/registries/customized_api_response_registry'
require 'open_chain/custom_handler/custom_view_selector'
require 'open_chain/api/v1/core_module_api_json_support'

module OpenChain; module Api; module V1; class ShipmentApiJsonGenerator
  include OpenChain::Api::V1::ApiJsonControllerAdapter
  include ActionView::Helpers::NumberHelper
  include OpenChain::Api::V1::CoreModuleApiJsonSupport

  def initialize jsonizer: nil
    # As of this moment, the generic shipment screen requires a slightly customized jsonizer instance that outputs
    # numbers as floats (rather than the rails default) and no nil values.
    jsonizer = (jsonizer || OpenChain::Api::ApiEntityJsonizer.new(force_big_decimal_numeric:true, blank_if_nil:true))
    super(core_module: CoreModule::SHIPMENT, jsonizer: jsonizer)
  end

  def obj_to_json_hash s
    headers_to_render = limit_fields(field_list(CoreModule::SHIPMENT))

    container_fields_to_render = field_list(CoreModule::CONTAINER)

    h = {id: s.id}
    headers_to_render.each {|uid| h[uid] = export_field(uid, s)}
    if render_shipment_lines?
      h['lines'] = render_lines(preload_shipment_lines(s, render_order_fields?, true), shipment_line_fields_to_render, render_order_fields?)
    end
    if render_booking_lines?
      h['booking_lines'] = render_lines(preload_booking_lines(s), booking_line_fields_to_render)
    end

    if render_containers?
      h['containers'] = render_lines(s.containers, container_fields_to_render)
    end

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

    if render_booked_orders?
      h["booked_orders"] = render_booked_orders(s)
    end

    h['permissions'] = render_permissions(s)
    custom_view = OpenChain::CustomHandler::CustomViewSelector.shipment_view(s,current_user)
    if !custom_view.blank?
      h['custom_view'] = custom_view
    end

    h['screen_settings'] = JSON.parse(KeyJsonItem.shipment_settings(s.importer.try(:system_code)).first.try(:json_data) || '{}')

    render_state_toggle_buttons(s, current_user, api_hash: h, params: params)

    OpenChain::Registries::CustomizedApiResponseRegistry.customize_shipment_response(s, current_user, h, params)

    h
  end

  def render_lines (lines, fields_to_render, with_order_lines=false)
    lines.map do |sl|
      rendered_line = {id: sl.id}
      fields_to_render.each {|uid| rendered_line[uid] = export_field(uid, sl)}
      rendered_line['order_lines'] = render_order_fields(sl) if with_order_lines
      rendered_line
    end
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

  def booking_line_fields_to_render
    limit_fields(field_list(CoreModule::BOOKING_LINE))
  end

  def shipment_line_fields_to_render
    limit_fields(field_list(CoreModule::SHIPMENT_LINE))
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
    params[:include].to_s.match(/shipment_lines/) || params[:shipment_lines].present? || params[:action] == 'create'
  end
  def render_booking_lines?
    params[:include].to_s.match(/booking_lines/) || params[:booking_lines].present? || params[:action] == 'create'
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
    params[:include].to_s.match(/summary/) ||params[:summary]
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

  def render_comments?
    params[:include].present? && params[:include].match(/comments/)
  end

  def render_comments s, user
    s.comments.map {|c| c.comment_json(user) }
  end

  def render_containers?
    params[:include].to_s.match(/containers/)
  end

  def render_booked_orders?
    params[:include].to_s.match(/booked_orders/)
  end

  def render_booked_orders shipment
    orders = {}
    shipment.booking_lines.each do |line|
      # This is mostly done this way to not inflate associations for every line needlessly (like when the same order
      # is booked on several lines) .. only those we actually will render
      if line.order_id.to_i != 0 && orders[line.order_id].nil?
        orders[line.order_id] = line.order
      end
    end

    g = OpenChain::Api::V1::OrderApiJsonGenerator.new
    g.json_context = self.json_context

    orders.values.map {|o| g.obj_to_json_hash o }
  end

end; end; end; end;