require 'open_chain/api/v1/tpp_hts_override_api_json_generator'

module Api; module V1; class TppHtsOverridesController < Api::V1::ApiCoreModuleControllerBase

  def core_module
    CoreModule::TPP_HTS_OVERRIDE
  end

  def save_object h
    o = h['id'].blank? ? TppHtsOverride.new : TppHtsOverride.includes(
      {custom_values:[:custom_definition]}
    ).find_by_id(h['id'])
    raise StatusableError.new("Object with id #{h['id']} not found.", 404) if o.nil?
    validate_trade_preference_program_not_changed h, o
    import_fields h, o, core_module
    raise StatusableError.new("You do not have permission to save this HTS Override.", :forbidden) unless o.can_edit?(current_user)
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

  def json_generator
    OpenChain::Api::V1::TppHtsOverrideApiJsonGenerator.new
  end
end; end; end;
