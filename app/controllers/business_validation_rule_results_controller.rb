class BusinessValidationRuleResultsController < ApplicationController
  include ValidationResultsHelper
  def update
    rr = BusinessValidationRuleResult.find params[:id]
    return error_redirect "You do not have permission to perform this activity." unless rr.can_edit? current_user
    rr.update_attributes(sanitized_attributes(params[:business_validation_rule_result]))
    rr.overridden_at = Time.now
    rr.overridden_by = current_user
    rr.save!
    bvr = BusinessValidationResult.find rr.business_validation_result_id
    bvr.run_validation # reset result state
    bvr.save!
    respond_to do |format|
      format.html {
        redirect_to validation_results_entry_path(rr.business_validation_result.validatable)
      }
      format.json {
        render json: {save_response:{
          validatable_state:bvr.validatable.business_rules_state,
          result_state:bvr.state,
          rule_result:business_validation_rule_result_json(rr)
        }} 

      }
    end
  end

  private
  def sanitized_attributes a
    r = {}
    r[:note] = a[:note]
    r[:state] = a[:state]
    r
  end
end
