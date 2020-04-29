require 'open_chain/business_rule_validation_results_support'
require 'open_chain/api/v1/company_api_json_generator'

module Api; module V1; class VendorsController < Api::V1::ApiCoreModuleControllerBase
  include OpenChain::BusinessRuleValidationResultsSupport

  def core_module
    CoreModule::COMPANY
  end

  def index
    # filter down to vendors only
    params[:sid999] = 'cmp_vendor'
    params[:sop999] = 'notnull'
    render_search core_module
  end

  def show
    render_show core_module
  end

  def update
    do_update core_module
  end

  def create
    do_create core_module
  end

  def validate
    vend = Company.find params[:id]
    run_validations vend
  end

  def save_object h
    c = h['id'].blank? ? Company.new(vendor:true) : Company.includes({custom_values:[:custom_definition]}).find_by_id(h['id'])
    raise StatusableError.new("Object with id #{h['id']} not found.", 404) if c.nil?
    import_fields h, c, CoreModule::COMPANY
    raise StatusableError.new("You do not have permission to save this Company.", :forbidden) unless c.can_edit?(current_user)
    c.vendor = true # always force if through this API
    c.save if c.errors.full_messages.blank?
    c
  end

  def json_generator
    OpenChain::Api::V1::CompanyApiJsonGenerator.new
  end

end; end; end
