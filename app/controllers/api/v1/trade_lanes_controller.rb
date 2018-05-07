require 'open_chain/api/v1/trade_lane_api_json_generator'

module Api; module V1; class TradeLanesController < Api::V1::ApiCoreModuleControllerBase

  def core_module
    CoreModule::TRADE_LANE
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

  def json_generator
    OpenChain::Api::V1::TradeLaneApiJsonGenerator.new
  end
  
end; end; end
