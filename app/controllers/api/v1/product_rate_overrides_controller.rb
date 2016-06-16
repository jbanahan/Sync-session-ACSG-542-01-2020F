module Api; module V1; class ProductRateOverridesController < Api::V1::ApiCoreModuleControllerBase
  def core_module
    CoreModule::PRODUCT_RATE_OVERRIDE
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
    cu = current_user #current_user is method, so saving as variable to prevent multiple calls
    {
      can_view: obj.can_view?(cu),
      can_edit: obj.can_edit?(cu)
    }
  end
  def save_object h
    pro = h['id'].blank? ? ProductRateOverride.new : ProductRateOverride.includes(
      {custom_values:[:custom_definition]}
    ).find_by_id(h['id'])
    raise StatusableError.new("Object with id #{h['id']} not found.",404) if pro.nil?
    import_fields h, pro, CoreModule::PRODUCT_RATE_OVERRIDE
    raise StatusableError.new("You do not have permission to save this Trade Lane.",:forbidden) unless pro.can_edit?(current_user)
    pro.save if pro.errors.full_messages.blank?
    pro
  end
end; end; end
