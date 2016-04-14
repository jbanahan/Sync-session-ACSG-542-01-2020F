module Api; module V1; class TradeLanesController < Api::V1::ApiCoreModuleControllerBase
  def core_module
    CoreModule::TRADE_LANE
  end

  def index
    render_search CoreModule::TRADE_LANE
  end

  def show
    render_show CoreModule::TRADE_LANE
  end

  def create
    do_create CoreModule::TRADE_LANE
  end

  def update
    do_update CoreModule::TRADE_LANE
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
    cu = current_user #current_user is method, so saving as variable to prevent multiple calls
    {
      can_view: obj.can_view?(cu),
      can_edit: obj.can_edit?(cu),
      can_attach: obj.can_attach?(cu),
      can_comment: obj.can_comment?(cu)
    }
  end

  def save_object h
    tl = h['id'].blank? ? TradeLane.new : TradeLane.includes(
      {custom_values:[:custom_definition]}
    ).find_by_id(h['id'])
    raise StatusableError.new("Object with id #{h['id']} not found.",404) if tl.nil?
    import_fields h, tl, CoreModule::TRADE_LANE
    raise StatusableError.new("You do not have permission to save this Trade Lane.",:forbidden) unless tl.can_edit?(current_user)
    tl.save if tl.errors.full_messages.blank?
    tl
  end
end; end; end
