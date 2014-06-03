class ProjectsController < ApplicationController
  include ProjectsHelper
  def index
    if !current_user.view_projects?
      error_redirect "You do not have permission to view projects."
      return
    end
    @projects = Project.scoped
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
    p.on_hold = false
    p.save
    unless p.errors.blank?
      return render_json_error p.errors.full_messages.join('\n'), 400
    end
    render_project p
  end

  def toggle_on_hold
    p = Project.find params[:id]
    if !p.can_edit? current_user
      return render_json_error "You do not have permission to edit this project.", 401
    elsif !p.closed_at.blank? #They shouldn't get here from the UI anyway, but just in case
      return render_json_error "Closed projects can not be put on hold.", 401
    end
    p.on_hold = !p.on_hold
    p.save
    unless p.errors.blank?
      return render_json_error p.errors.full_messages.join('\n'), 400
    end
    render_project p
  end

  def add_project_set
    if params[:project_set_name].blank?
      return render_json_error "Project Set Name cannot be blank.", 400
    end
    p = Project.find params[:id]
    if !p.can_edit? current_user
      return render_json_error "You do not have permission to edit this project.", 401
    end
    if p.project_sets.where(name:params[:project_set_name].strip).empty?
      ps = ProjectSet.where(name:params[:project_set_name].strip).first_or_create
      if !ps.errors.blank?
        return render_json_error ps.errors.full_messages.join('\n'), 400
      end
      p.project_sets << ps
    end
    p.updated_at = 0.seconds.ago
    p.save!
    render_project p
  end

  def remove_project_set
    if params[:project_set_name].blank?
      return render_json_error "Project Set Name cannot be blank.", 400
    end
    p = Project.find params[:id]
    if !p.can_edit? current_user
      return render_json_error "You do not have permission to edit this project.", 401
    end
    ps = ProjectSet.find_by_name params[:project_set_name].strip
    ps.projects.destroy(p) if ps
    ps.destroy if ps && ps.projects.empty?
    p.update_attributes(updated_at:0.seconds.ago)
    render_project p
  end
end
