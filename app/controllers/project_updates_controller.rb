class ProjectUpdatesController < ApplicationController
  include ProjectsHelper
  def index
    p = Project.includes(:project_updates).find params[:project_id]
    unless p.can_view? current_user
      return render_json_error "You do not have permission to view this project.", 401
    end
    r = []
    p.project_updates.each do |pu|
      r << project_update_hash(pu)
    end
    render json: {project_updates:r}
  end
  def create
    p = Project.find params[:project_id]
    unless p.can_edit? current_user
      return render_json_error "You do not have permission to edit this project.", 401
    end
    pu = p.project_updates.new(params[:project_update])
    pu.created_by = current_user
    pu.save
    unless pu.errors.blank?
      return render_json_error pu.errors.full_messages.join('\n'), 400
    end
    render json: {project_update:project_update_hash(pu)}
  end
  def update

  end
end
