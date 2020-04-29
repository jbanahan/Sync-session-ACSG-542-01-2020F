require 'open_chain/api/v1/product_rate_override_api_json_generator'

module Api; module V1; class ProductRateOverridesController < Api::V1::ApiCoreModuleControllerBase
  def core_module
    CoreModule::PRODUCT_RATE_OVERRIDE
  end

  def save_object h
    pro = h['id'].blank? ? ProductRateOverride.new : ProductRateOverride.includes(
      {custom_values:[:custom_definition]}
    ).find_by_id(h['id'])
    raise StatusableError.new("Object with id #{h['id']} not found.", 404) if pro.nil?
    import_fields h, pro, CoreModule::PRODUCT_RATE_OVERRIDE
    raise StatusableError.new("You do not have permission to save this Trade Lane.", :forbidden) unless pro.can_edit?(current_user)
    pro.save if pro.errors.full_messages.blank?
    pro
  end

  def json_generator
    OpenChain::Api::V1::ProductRateOverrideApiJsonGenerator.new
  end

end; end; end
