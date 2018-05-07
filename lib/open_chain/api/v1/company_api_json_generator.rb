require 'open_chain/api/v1/api_json_controller_adapter'

module OpenChain; module Api; module V1; class CompanyApiJsonGenerator
  include OpenChain::Api::V1::ApiJsonControllerAdapter

  def initialize jsonizer: nil
    super(core_module: CoreModule::COMPANY, jsonizer: jsonizer)
  end

  def obj_to_json_hash c
    headers_to_render = limit_fields([
      :cmp_sys_code,
      :cmp_name,
      :cmp_created_at,
      :cmp_updated_at,
      :cmp_enabled_booking_types,
    ]) + custom_field_keys(CoreModule::COMPANY)
    h = to_entity_hash(c,headers_to_render)
    h['permissions'] = render_permissions(c)
    h
  end

  private
    def render_permissions c
      cu = current_user #current_user is method, so saving as variable to prevent multiple calls
      {
        can_view: c.can_view?(cu),
        can_edit: c.can_edit?(cu),
        can_attach: c.can_attach?(cu),
        can_comment: c.can_comment?(cu)
      }
    end
end; end; end; end;