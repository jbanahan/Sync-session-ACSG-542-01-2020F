class ProjectDeliverablesController < ApplicationController
  include ProjectsHelper
  def create
    p = Project.find params[:project_id]
    unless p.can_edit? current_user
      return render_json_error "You do not have permission to edit this project.", 401
    end
    pd = p.project_deliverables.new(sanitize_project_deliverable_params params[:project_deliverable])
    pd.save
    unless pd.errors.blank?
      return render_json_error pd.errors.full_messages.join('\n'), 400
    end
    render json: {project_deliverable:project_deliverable_hash(pd)}
  end
  def update
    pd = ProjectDeliverable.find params[:id]
    unless pd.can_edit? current_user
      return render_json_error "You do not have permission to edit this project.", 401
    end
    pd.update_attributes(sanitize_project_deliverable_params params[:project_deliverable])
    pd.save
    unless pd.errors.blank?
      return render_json_error pd.errors.full_messages.join('\n'), 400
    end
    render json: {project_deliverable:project_deliverable_hash(pd)}
  end
end
