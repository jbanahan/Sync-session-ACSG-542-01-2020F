module Api; module V1; class OrdersController < Api::V1::ApiCoreModuleControllerBase
  def core_module
    CoreModule::ORDER
  end
  def index
    render_search CoreModule::ORDER
  end

  def show
    render_show CoreModule::ORDER
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
      :ord_approval_status
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
      :ordln_total_cost
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
    h
  end
end; end; end