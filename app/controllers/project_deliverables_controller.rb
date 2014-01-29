class ProjectDeliverablesController < ApplicationController
  include ProjectsHelper
  def index
    respond_to do |format|
      format.html {
        return error_redirect "You do not have permission to view projects." unless current_user.view_projects? 
      }
      format.json {
        return render_json_error "You do not have permission to view projects.", 401 unless current_user.view_projects?
        dbu = {}
        ProjectDeliverable.search_secure(current_user, ProjectDeliverable.incomplete.not_closed.order("due_date ASC")).each do |d|
          h = project_deliverable_hash(d)
          nm = d.assigned_to.blank? ? '' : d.assigned_to.full_name
          dd = (d.due_date.nil?) ? 'No Due Date' : d.due_date.beginning_of_week.strftime('Week of %Y-%m-%d')
          top_level = nil
          mid_level = nil
          case params[:layout]
          when 'project'
            top_level = d.project.name
            mid_level = nm
          when 'weekproject'
            top_level = dd 
            mid_level = d.project.name
          when 'weekuser'
            top_level = dd 
            mid_level = nm
          else
            top_level = nm
            mid_level = d.project.name
          end
          dbu[top_level] ||= {}
          dbu[top_level][mid_level] ||= []
          dbu[top_level][mid_level] << h
        end
        render json: {deliverables_by_user: dbu}
      }
    end
    #don't map by user here so we don't execute the relation if the view will be cached
  end
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
