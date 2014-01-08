class ProjectsController < ApplicationController
  include ProjectsHelper
  def index
    if !current_user.view_projects?
      error_redirect "You do not have permission to view projects."
      return
    end
    @projects = Project.all
  end

  def show
    respond_to do |format|
      format.html {
        @no_action_bar = true #angular action bar used
        @project_id = params[:id]
      }
      format.json {
        p = Project.includes(:project_updates).find params[:id]
        if !p.can_view? current_user
          return render_json_error "You do not have permission to view this project.", 401
        end
        render_project p
      }
    end
  end

  def update
    p = Project.find params[:id]
    if !p.can_edit? current_user
      return render_json_error "You do not have permission to edit this project.", 401
    end
    p.update_attributes(sanitize_project_params params[:project])
    unless p.errors.blank?
      return render_json_error p.errors.full_messages.join('\n'), 400
    end
    render_project p
  end

  def create
    if !current_user.edit_projects?
      error_redirect "You do not have permission to create projects."
      return
    end
    p = Project.create(sanitize_project_params params[:project])
    if !p.errors.blank?
      error_redirect p.errors.full_messages.join('\n')
      return
    end
    redirect_to p
  end

  def toggle_close
    p = Project.find params[:id]
    if !p.can_edit? current_user
      return render_json_error "You do not have permission to edit this project.", 401
    end
    p.closed_at = p.closed_at.blank? ? 0.seconds.ago : nil
    p.save
    unless p.errors.blank?
      return render_json_error p.errors.full_messages.join('\n'), 400
    end
    render_project p
  end

end
