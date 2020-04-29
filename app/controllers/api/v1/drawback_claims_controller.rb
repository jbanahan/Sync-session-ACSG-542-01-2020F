require 'open_chain/business_rule_validation_results_support'

module Api; module V1; class DrawbackClaimsController < Api::V1::ApiCoreModuleControllerBase
  include OpenChain::BusinessRuleValidationResultsSupport

  def validate
    dc = DrawbackClaim.find params[:id]
    run_validations dc
  end

end; end; end