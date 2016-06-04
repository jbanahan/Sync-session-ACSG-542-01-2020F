module Api; module V1; class TppHtsOverridesController < Api::V1::ApiCoreModuleControllerBase
  def core_module
    CoreModule::TPP_HTS_OVERRIDE
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
      :tpphtso_hts_code,
      :tpphtso_rate,
      :tpphtso_note,
      :tpphtso_trade_preference_program_id
    ] + custom_field_keys(core_module))

    h = to_entity_hash(obj, headers_to_render)
    h['permissions'] = render_permissions(obj)
    h
  end
  def render_permissions obj
    cu = current_user
    {
      can_view: obj.can_view?(cu),
      can_edit: obj.can_edit?(cu),
      can_attach: obj.can_attach?(cu),
      can_comment: obj.can_comment?(cu)
    }
  end
  def save_object h
    o = h['id'].blank? ? TppHtsOverride.new : TppHtsOverride.includes(
      {custom_values:[:custom_definition]}
    ).find_by_id(h['id'])
    raise StatusableError.new("Object with id #{h['id']} not found.",404) if o.nil?
    validate_trade_preference_program_not_changed h, o
    import_fields h, o, core_module
    raise StatusableError.new("You do not have permission to save this HTS Override.",:forbidden) unless o.can_edit?(current_user)
    raise StatusableError.new("Object cannot be saved without a valid tpphtso_trade_preference_program_id value.") unless o.trade_preference_program_id && o.trade_preference_program
    o.save!
    o
  end

  def validate_trade_preference_program_not_changed hash, object
    h_id = hash['tpphtso_trade_preference_program_id']
    o_id = object.trade_preference_program_id
    return if h_id.blank?
    return if o_id.blank?
    if h_id != o_id
      raise StatusableError.new("You cannot change the Tariff Preference Program via the API.")
    end
  end
end; end; end;
