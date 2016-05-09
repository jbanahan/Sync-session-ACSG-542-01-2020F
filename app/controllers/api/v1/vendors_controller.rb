require 'open_chain/business_rule_validation_results_support'

module Api; module V1; class VendorsController < Api::V1::ApiCoreModuleControllerBase
  include OpenChain::BusinessRuleValidationResultsSupport

  def validate 
    vend = Company.find params[:id]
    run_validations vend
  end

end; end; end    