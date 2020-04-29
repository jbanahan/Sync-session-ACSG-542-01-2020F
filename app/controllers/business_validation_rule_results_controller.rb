class BusinessValidationRuleResultsController < ApplicationController
  include ValidationResultsHelper
  def update
    rr = BusinessValidationRuleResult.find params[:id]
    return error_redirect "You do not have permission to perform this activity." unless rr.can_edit? current_user
    rr.update_attributes(sanitized_attributes(params[:business_validation_rule_result]))
    rr.overridden_at = Time.zone.now
    rr.overridden_by = current_user
    rr.save!
    # Technically, we could just validate the single result that was overridden, but by running create_results...
    # then we get history saved and anything else that needs to happen on a regular full business rule run.
    validatable = rr.business_validation_result.validatable
    BusinessValidationTemplate.create_results_for_object! validatable

    bvr = BusinessValidationResult.find rr.business_validation_result_id
    respond_to do |format|
      format.html {
        redirect_to validation_results_path(validatable)
      }
      format.json {
        render json: {save_response:{
          validatable_state:bvr.validatable.business_rules_state,
          result_state:bvr.state,
          rule_result:business_validation_rule_result_json(rr, current_user)
        }}

      }
    end
  end
  def cancel_override
    rr = BusinessValidationRuleResult.find params[:id]
    unless rr.can_edit? current_user
      render_json_error "You do not have permission to perform this activity."
      return
    end
    rr.cancel_override
    obj = rr.business_validation_result.validatable
    BusinessValidationTemplate.create_results_for_object! obj
    render json: {ok:'ok'}
  end

  private
  def sanitized_attributes a
    r = {}
    r[:note] = a[:note]
    r[:state] = a[:state]
    r
  end
end
