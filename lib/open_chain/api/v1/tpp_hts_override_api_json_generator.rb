require 'open_chain/api/v1/api_json_controller_adapter'

module OpenChain; module Api; module V1; class TppHtsOverrideApiJsonGenerator
  include OpenChain::Api::V1::ApiJsonControllerAdapter

  def initialize jsonizer: nil
    super(core_module: CoreModule::TPP_HTS_OVERRIDE, jsonizer: jsonizer)
  end

  def obj_to_json_hash obj
    headers_to_render = limit_fields([
      :tpphtso_hts_code,
      :tpphtso_rate,
      :tpphtso_note,
      :tpphtso_trade_preference_program_id,
      :tpphtso_start_date,
      :tpphtso_end_date,
      :tpphtso_active
    ] + custom_field_keys(core_module))

    h = to_entity_hash(obj, headers_to_render)
    h['permissions'] = render_permissions(obj)
    h
  end

  def render_permissions obj
    cu = current_user
    {
      can_view: obj.can_view?(cu),
      can_edit: obj.can_edit?(cu)
    }
  end
end; end; end; end;