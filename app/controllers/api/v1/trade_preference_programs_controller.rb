require 'open_chain/api/v1/trade_preference_program_api_json_generator'

module Api; module V1; class TradePreferenceProgramsController < Api::V1::ApiCoreModuleControllerBase

  def core_module
    CoreModule::TRADE_PREFERENCE_PROGRAM
  end

  def save_object h
    tpp = h['id'].blank? ? TradePreferenceProgram.new : TradePreferenceProgram.includes(
      {custom_values:[:custom_definition]}
    ).find_by_id(h['id'])
    raise StatusableError.new("Object with id #{h['id']} not found.", 404) if tpp.nil?
    import_fields h, tpp, core_module
    raise StatusableError.new("You do not have permission to save this Trade Lane.", :forbidden) unless tpp.can_edit?(current_user)
    tpp.save if tpp.errors.full_messages.blank?
    tpp
  end

  def json_generator
    OpenChain::Api::V1::TradePreferenceProgramApiJsonGenerator.new
  end
end; end; end
