module Api; module V1; class TradePreferenceProgramsController < Api::V1::ApiCoreModuleControllerBase
  def core_module
    CoreModule::TRADE_PREFERENCE_PROGRAM
  end

  def index
    render_search core_module
  end

  def show
    render_show core_module
  end

  def create
    do_create core_module
  end

  def update
    do_update core_module
  end

  def obj_to_json_hash obj
    headers_to_render = limit_fields([
      :tpp_tariff_adjustment_percentage,
      :tpp_updated_at,
      :tpp_created_at,
      :tpp_origin_cntry_name,
      :tpp_origin_cntry_iso,
      :tpp_destination_cntry_name,
      :tpp_destination_cntry_iso,
      :tpp_tariff_identifier,
      :tpp_name
    ] + custom_field_keys(core_module))

    h = to_entity_hash(obj, headers_to_render)
    h['permissions'] = render_permissions(obj)
    h
  end
  def render_permissions obj
    cu = current_user #current_user is method, so saving as variable to prevent multiple calls
    {
      can_view: obj.can_view?(cu),
      can_edit: obj.can_edit?(cu),
      can_attach: obj.can_attach?(cu),
      can_comment: obj.can_comment?(cu)
    }
  end

  def save_object h
    tpp = h['id'].blank? ? TradePreferenceProgram.new : TradePreferenceProgram.includes(
      {custom_values:[:custom_definition]}
    ).find_by_id(h['id'])
    raise StatusableError.new("Object with id #{h['id']} not found.",404) if tpp.nil?
    import_fields h, tpp, core_module
    raise StatusableError.new("You do not have permission to save this Trade Lane.",:forbidden) unless tpp.can_edit?(current_user)
    tpp.save if tpp.errors.full_messages.blank?
    tpp
  end
end; end; end
