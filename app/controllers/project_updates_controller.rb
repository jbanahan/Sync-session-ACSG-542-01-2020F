class ProjectUpdatesController < ApplicationController
  include ProjectsHelper
  def create
    p = Project.find params[:project_id]
    unless p.can_edit? current_user
      return render_json_error "You do not have permission to edit this project.", 401
    end
    pu = p.project_updates.new(sanitize_project_update_params params[:project_update])
    pu.created_by = current_user
    pu.save
    unless pu.errors.blank?
      return render_json_error pu.errors.full_messages.join('\n'), 400
    end
    render json: {project_update:project_update_hash(pu)}
  end
  def update
    pu = ProjectUpdate.find params[:id]
    unless pu.can_edit? current_user
      return render_json_error "You do not have permission to edit this project.", 401
    end
    unless pu.created_by == current_user
      return render_json_error "You cannot edit updates unless you created them.", 401
    end
    pu.update_attributes(sanitize_project_update_params params[:project_update])
    pu.save
    unless pu.errors.blank?
      return render_json_error pu.errors.full_messages.join('\n'), 400
    end
    render json: {project_update:project_update_hash(pu)}
  end
end
