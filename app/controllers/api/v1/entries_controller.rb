require 'open_chain/business_rule_validation_results_support'

module Api; module V1; class EntriesController < Api::V1::ApiCoreModuleControllerBase
  include OpenChain::BusinessRuleValidationResultsSupport

  def validate 
    ent = Entry.find params[:id]
    run_validations ent
  end

end; end; end    