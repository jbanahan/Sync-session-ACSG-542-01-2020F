class CorrectiveActionPlansController < ApplicationController
  def show 
    cap = SurveyResponse.find(params[:survey_response_id]).corrective_action_plan
    do_show cap
  end
  def update
    cap = CorrectiveActionPlan.find params[:id]
    unless params[:comment].blank? || !cap.can_view?(current_user)
      cap.comments.create!(body:params[:comment],user:current_user)
    end
    cap_params = params[:corrective_action_plan]
    if cap_params && cap_params[:corrective_issues]
      c_edit = cap.can_edit?(current_user)
      c_upd_act = cap.can_update_actions?(current_user)
      cap_params[:corrective_issues].each do |cip|
        next if cip['id'].blank? && !c_edit
        ci = cip['id'].blank? ? cap.corrective_issues.build : cap.corrective_issues.find(cip['id'])
        ci.description = cip['description'] if c_edit
        ci.suggested_action = cip['suggested_action'] if c_edit
        ci.action_taken = cip['action_taken'] if c_upd_act
        ci.save!
      end
    end
    if cap.status == cap.class::STATUSES[:active]
      OpenMailer.delay.send_survey_user_update(cap.survey_response,true) unless cap.assigned_user?(current_user)
      cap.survey_response.delay.notify_subscribers(true)
    end
    do_show(cap)
  end
  def create
    sr = SurveyResponse.find(params[:survey_response_id])
    if !sr.can_edit? current_user
      error_redirect "You cannot create a corrective action plan for this survey."
      return
    end
    cap = sr.corrective_action_plan.nil? ? sr.create_corrective_action_plan!(created_by_id:current_user.id) : sr.corrective_action_plan
    redirect_to [sr,cap]
  end
  def activate
    update_status :active, :activate, :activated
  end
  def resolve
    update_status :resolved, :resolve, :resolved  
  end
  def destroy
    cap = CorrectiveActionPlan.find(params[:id])
    if !cap.can_delete? current_user
      error_redirect "You cannot delete this plan."
      return
    end
    sr = cap.survey_response
    cap.destroy
    add_flash :notices, "Plan deleted."
    redirect_to sr
  end

  private
  def update_status status, verb_present, verb_past
    sr = SurveyResponse.find(params[:survey_response_id])
    cap = sr.corrective_action_plan
    if cap.nil?
      error_redirect "There isn't a plan to #{verb_present}."
      return
    end
    if !cap.can_edit? current_user
      error_redirect "You cannot #{verb_present} this plan." 
      return
    end
    cap.update_attributes(status: CorrectiveActionPlan::STATUSES[status])
    add_flash :notices, "Plan #{verb_past}."
    OpenMailer.delay.send_survey_user_update(cap.survey_response,true) unless cap.assigned_user?(current_user)
    redirect_to [sr,cap]
  end
  def do_show cap
    if !cap.can_view? current_user
      error_redirect "You cannot view this corrective action plan."
      return
    end
    respond_to do |format|
      format.html {@cap = cap}
      format.json {
        j = cap.as_json(
          include:{
            corrective_issues: {
              methods:[:html_description,:html_suggested_action,:html_action_taken]
            },
            comments: {
              methods:[:html_body],
              include:{
                user:{
                  methods:[:full_name]
                }
              }
            }
          }
        )
        j[:can_edit] = cap.can_edit?(current_user)
        j[:can_update_actions] = cap.can_update_actions?(current_user)
        render json: j
      }
    end
  end
end
