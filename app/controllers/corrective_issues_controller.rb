class CorrectiveIssuesController < ApplicationController

  def update
    ci = CorrectiveIssue.find params[:id]
    cap = ci.corrective_action_plan
    if !cap.can_view? current_user
      render json: {error:'You do not have permission to view this object.'}, status: 401
      return
    end
    params_to_update = {} 
    fields_to_update = []
    fields_to_update += [:description,:suggested_action] if cap.can_edit? current_user
    fields_to_update += [:action_taken] if cap.can_update_actions? current_user
    fields_to_update.each {|x| params_to_update[x] = params[:corrective_issue][x]}
    ci.update_attributes(params_to_update)
    cap.log_update current_user 
    render json: ci
  end

  def create
    cap = CorrectiveActionPlan.find params[:corrective_action_plan_id]
    if cap.can_edit? current_user
      ci = cap.corrective_issues.create!
      render json: ci
    else
      render json: {error:"You do not have permission to work with this object."}, status: 401
    end
  end
  def destroy
    ci = CorrectiveIssue.find params[:id] 
    cap = ci.corrective_action_plan
    if !cap.can_edit? current_user
      render json: {error:"You do not have permission to work with this object."}, status: 401
      return
    end
    if cap.status!=CorrectiveActionPlan::STATUSES[:new]
      render json: {error:'You canot remove issues from an active plan'}, status: 400
      return
    end
    ci.destroy
    render json: {ok: 'ok'}
  end
end
