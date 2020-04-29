require 'open_chain/api/v1/api_json_controller_adapter'

module OpenChain; module Api; module V1; class ProductRateOverrideApiJsonGenerator
  include OpenChain::Api::V1::ApiJsonControllerAdapter

  def initialize jsonizer: nil
    super(core_module: CoreModule::PRODUCT_RATE_OVERRIDE, jsonizer: jsonizer)
  end

  def obj_to_json_hash obj
    headers_to_render = limit_fields([
      :pro_rate,
      :pro_notes,
      :pro_updated_at,
      :pro_created_at,
      :pro_origin_cntry_name,
      :pro_origin_cntry_iso,
      :pro_destination_cntry_name,
      :pro_destination_cntry_iso,
      :pro_product_id,
      :pro_active
    ] + custom_field_keys(CoreModule::TRADE_LANE))

    h = to_entity_hash(obj, headers_to_render)
    h['permissions'] = render_permissions(obj)
    h
  end

  def render_permissions obj
    cu = current_user # current_user is method, so saving as variable to prevent multiple calls
    {
      can_view: obj.can_view?(cu),
      can_edit: obj.can_edit?(cu)
    }
  end

end; end; end; end;