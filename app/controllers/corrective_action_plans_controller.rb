class CorrectiveActionPlansController < ApplicationController
  include SurveyResponsesControllerSupport

  def show
    cap = SurveyResponse.find(params[:survey_response_id]).corrective_action_plan
    do_show cap
  end
  def update
    cap = CorrectiveActionPlan.find params[:id]
    unless params[:comment].blank? || !cap.can_view?(current_user)
      cap.comments.create!(body:params[:comment], user:current_user)
      cap.log_update current_user
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
    redirect_to [sr, cap]
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

  # adds a comment returning the comment json unless the comment submitted was blank, then it returns
  # a json like {error:'Empty comment not added'} with 400 status
  def add_comment
    cap = CorrectiveActionPlan.find params[:id]
    if params[:comment].blank?
      render json: {error: 'Empty comment not added'}, status: 400
      return
    end
    if !cap.can_view? current_user
      render json: {error: 'Permission denied.'}, status: 401
      return
    end
    c = cap.comments.create! user: current_user, body: params[:comment]
    cap.log_update current_user
    render json: c.to_json(methods:[:html_body], include:{user:{methods:[:full_name], only:[:email]}})
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
    cap.log_update current_user
    redirect_to [sr, cap]
  end
  def do_show cap
    if !cap.can_view? current_user
      error_redirect "You cannot view this corrective action plan."
      return
    end
    respond_to do |format|
      format.html {@cap = cap}
      format.json {
        render json: corrective_action_plan_json(cap, current_user)
      }
    end
  end
end
