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
    headers_to_render = limit_fields(field_list(CoreModule::ORDER))
    line_fields_to_render = limit_fields(field_list(CoreModule::ORDER_LINE))

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