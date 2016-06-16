require 'open_chain/business_rule_validation_results_support'

module Api; module V1; class OrdersController < Api::V1::ApiCoreModuleControllerBase
  include OpenChain::BusinessRuleValidationResultsSupport

  def core_module
    CoreModule::ORDER
  end

  def by_order_number
    obj = Order.where(order_number: params[:order_number]).first
    render_obj obj
  end

  def accept
    o = Order.find params[:id]
    unless o.can_view?(current_user) && o.can_accept?(current_user)
      raise StatusableError.new("Access denied.", :unauthorized)
    end
    raise StatusableError.new("Order #{o.order_number} cannot be accepted at this time.") unless o.can_be_accepted?
    o.async_accept! current_user
    redirect_to "/api/v1/orders/#{o.id}"
  end

  def unaccept
    o = Order.find params[:id]
    raise StatusableError.new("Access denied.", :unauthorized) unless o.can_view?(current_user) && o.can_accept?(current_user)
    o.async_unaccept! current_user
    redirect_to "/api/v1/orders/#{o.id}"
  end

  def save_object h
    ord = h['id'].blank? ? Order.new : Order.includes([
      {order_lines: [:piece_sets,{custom_values:[:custom_definition]},:product]},
      {custom_values:[:custom_definition]}
    ]).find_by_id(h['id'])
    raise StatusableError.new("Object with id #{h['id']} not found.",404) if ord.nil?
    import_fields h, ord, CoreModule::ORDER
    raise StatusableError.new("You do not have permission to save this Order.",:forbidden) unless ord.can_edit?(current_user)
    ord.save if ord.errors.full_messages.blank?
    ord
  end

  def obj_to_json_hash o
    headers_to_render = limit_fields([
      :ord_ord_num,
      :ord_cust_ord_no,
      :ord_imp_name,
      :ord_imp_syscode,
      :ord_mode,
      :ord_ord_date,
      :ord_ven_name,
      :ord_ven_syscode,
      :ord_window_start,
      :ord_window_end,
      :ord_first_exp_del,
      :ord_fob_point,
      :ord_currency,
      :ord_payment_terms,
      :ord_terms,
      :ord_total_cost,
      :ord_approval_status,
      :ord_order_from_address_name,
      :ord_order_from_address_full_address,
      :ord_ship_to_count,
      :ord_ship_from_id,
      :ord_ship_from_full_address,
      :ord_ship_from_name,
      :ord_rule_state,
      :ord_closed_at
    ] + custom_field_keys(CoreModule::ORDER))
    line_fields_to_render = limit_fields([
      :ordln_line_number,
      :ordln_puid,
      :ordln_pname,
      :ordln_ppu,
      :ordln_currency,
      :ordln_ordered_qty,
      :ordln_country_of_origin,
      :ordln_hts,
      :ordln_sku,
      :ordln_unit_of_measure,
      :ordln_total_cost,
      :ordln_ship_to_full_address
    ] + custom_field_keys(CoreModule::ORDER_LINE))

    if !line_fields_to_render.blank?
      o.freeze_all_custom_values_including_children
      o.order_lines.each {|ol| ol.product.try(:freeze_custom_values)}
    end
    h = to_entity_hash(o, headers_to_render + line_fields_to_render)
    custom_view = OpenChain::CustomHandler::CustomViewSelector.order_view(o,current_user)
    if !custom_view.blank?
      h['custom_view'] = custom_view
    end
    h['vendor_id'] = o.vendor_id
    h['permissions'] = render_permissions(o)
    h
  end
  def render_permissions order
    cu = current_user #current_user is method, so saving as variable to prevent multiple calls
    {
      can_view: order.can_view?(cu),
      can_edit: order.can_edit?(cu),
      can_accept: order.can_accept?(cu),
      can_be_accepted: order.can_be_accepted?,
      can_attach: order.can_attach?(cu),
      can_comment: order.can_comment?(cu)
    }
  end

  def validate
    ord = Order.find params[:id]
    run_validations(ord)
  end

end; end; end
