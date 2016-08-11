require 'open_chain/business_rule_validation_results_support'

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

  def save_object h
    c = h['id'].blank? ? Company.new(vendor:true) : Company.includes({custom_values:[:custom_definition]}).find_by_id(h['id'])
    raise StatusableError.new("Object with id #{h['id']} not found.",404) if c.nil?
    import_fields h, c, CoreModule::COMPANY
    raise StatusableError.new("You do not have permission to save this Company.",:forbidden) unless c.can_edit?(current_user)
    c.vendor = true #always force if through this API
    c.save if c.errors.full_messages.blank?
    c
  end

  def render_permissions c
    cu = current_user #current_user is method, so saving as variable to prevent multiple calls
    {
      can_view: c.can_view?(cu),
      can_edit: c.can_edit?(cu),
      can_attach: c.can_attach?(cu),
      can_comment: c.can_comment?(cu)
    }
  end

end; end; end
