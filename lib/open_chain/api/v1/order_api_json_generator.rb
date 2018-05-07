require 'open_chain/api/v1/api_json_controller_adapter'
require 'open_chain/registries/customized_api_response_registry'
require 'open_chain/custom_handler/custom_view_selector'
require 'open_chain/api/v1/core_module_api_json_support'

module OpenChain; module Api; module V1; class OrderApiJsonGenerator
  include OpenChain::Api::V1::ApiJsonControllerAdapter
  include OpenChain::Api::V1::CoreModuleApiJsonSupport

  def initialize jsonizer: nil
    super(core_module: CoreModule::ORDER, jsonizer: jsonizer)
  end

  def obj_to_json_hash o
    headers_to_render = limit_fields([
      :ord_ord_num,
      :ord_cust_ord_no,
      :ord_imp_id,
      :ord_imp_name,
      :ord_imp_syscode,
      :ord_mode,
      :ord_ord_date,
      :ord_ven_id,
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
      :ord_closed_at,
      :ord_tppsr_db_id,
      :ord_tppsr_name,
      :ord_rule_state
    ] + custom_field_keys(CoreModule::ORDER))
    line_fields_to_render = limit_fields([
      :ordln_line_number,
      :ordln_puid,
      :ordln_pname,
      :ordln_prod_db_id,
      :ordln_ppu,
      :ordln_currency,
      :ordln_ordered_qty,
      :ordln_country_of_origin,
      :ordln_hts,
      :ordln_sku,
      :ordln_unit_of_measure,
      :ordln_total_cost,
      :ordln_ship_to_full_address,
      :ordln_varuid,
      :ordln_var_db_id
    ] + custom_field_keys(CoreModule::ORDER_LINE))

    if !line_fields_to_render.blank?
      o.freeze_all_custom_values_including_children
      o.order_lines.each {|ol| ol.product.try(:freeze_custom_values)}
    end
    h = to_entity_hash(o, headers_to_render + line_fields_to_render)
    h['order_lines'].each {|olh| olh['order_id'] = o.id} if h['order_lines']
    custom_view = OpenChain::CustomHandler::CustomViewSelector.order_view(o,current_user)
    if !custom_view.blank?
      h['custom_view'] = custom_view
    end
    h['vendor_id'] = o.vendor_id
    h['permissions'] = render_permissions(o)
    h['available_tpp_survey_responses'] = render_tpp_surveys(o)
    render_state_toggle_buttons(o, current_user, api_hash: h, params: params)

    OpenChain::Registries::CustomizedApiResponseRegistry.customize_order_response(o, current_user, h, params)
    
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
      can_comment: order.can_comment?(cu),
      can_book: order.can_book?(cu)
    }
  end

  def render_tpp_surveys order
    order.available_tpp_survey_responses.collect {|sr| {id:sr.id,long_name:sr.long_name}}
  end

end; end; end; end;