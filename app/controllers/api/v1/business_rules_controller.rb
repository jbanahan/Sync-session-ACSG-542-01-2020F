require 'open_chain/business_rule_validation_results_support'
module Api; module V1; class BusinessRulesController < Api::V1::ApiController
  include OpenChain::BusinessRuleValidationResultsSupport
  def for_module
    obj = base_object params, :module_type, :id
    render_results obj
  end

  def refresh
    obj = base_object params, :module_type, :id
    raise StatusableError.new("You do not have permission to view business rules.",401) if !current_user.view_business_validation_results?
    BusinessValidationTemplate.create_results_for_object! obj
    render_results obj
  end

  #########
  # HELPERS
  #########

  def base_object params_base, module_type_param, id_param
    cm = CoreModule.find_by_class_name params_base[module_type_param]
    raise StatusableError.new("Module #{params_base[module_type_param]} not found.",404) unless cm
    k = cm.klass
    r = k.search_secure(current_user,k.where(id:params_base[id_param])).first
    raise StatusableError.new("#{cm.label} with id #{params_base[id_param]} not found.",404) unless r
    r
  end

  def render_results obj
    h = results_to_hsh(current_user,obj)
    raise StatusableError.new("You do not have permission to view business rules on this object.",401) if h.nil? || !current_user.view_business_validation_results?
    render json: {business_rules:h}
  end
end; end; end
