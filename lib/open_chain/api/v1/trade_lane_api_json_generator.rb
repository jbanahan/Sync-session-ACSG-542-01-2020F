require 'open_chain/api/v1/api_json_controller_adapter'

module OpenChain; module Api; module V1; class TradeLaneApiJsonGenerator
  include OpenChain::Api::V1::ApiJsonControllerAdapter

  def initialize jsonizer: nil
    super(core_module: CoreModule::TRADE_LANE, jsonizer: jsonizer)
  end

  def obj_to_json_hash obj
    headers_to_render = limit_fields([
      :lane_tariff_adjustment_percentage,
      :lane_notes,
      :lane_updated_at,
      :lane_created_at,
      :lane_origin_cntry_name,
      :lane_origin_cntry_iso,
      :lane_destination_cntry_name,
      :lane_destination_cntry_iso
    ] + custom_field_keys(CoreModule::TRADE_LANE))

    h = to_entity_hash(obj, headers_to_render)
    h['permissions'] = render_permissions(obj)
    h
  end

  def render_permissions obj
    cu = current_user # current_user is method, so saving as variable to prevent multiple calls
    {
      can_view: obj.can_view?(cu),
      can_edit: obj.can_edit?(cu),
      can_attach: obj.can_attach?(cu),
      can_comment: obj.can_comment?(cu)
    }
  end
end; end; end; end;