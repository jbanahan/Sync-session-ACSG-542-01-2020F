class ProjectDeliverablesController < ApplicationController
  include ProjectsHelper
  def index
    respond_to do |format|
      format.html {
        return error_redirect "You do not have permission to view projects." unless current_user.view_projects? 
      }
      format.json {
        return render_json_error "You do not have permission to view projects.", 401 unless current_user.view_projects?
        structure = params[:layout].blank? ? 'person' : params[:layout]
        dbu = {}
        if structure == 'projectset'
          ProjectSet.all.each do |ps|
            level_lambda = lambda {|structure,nm,d|
              [ps.name,d.project.name]
            }
            ProjectDeliverable.search_secure(current_user,ProjectDeliverable.incomplete.not_closed.where('project_id IN (SELECT project_id FROM project_sets_projects WHERE project_set_id = ?)',ps.id).order("due_date ASC")).each do |d|
              add_deliverable_for_index dbu, d, structure, level_lambda
            end
          end
          ProjectDeliverable.search_secure(current_user,ProjectDeliverable.incomplete.not_closed.where('NOT (project_id in (SELECT project_id FROM project_sets_projects))').order("due_date ASC")).each do |d|
            add_deliverable_for_index dbu, d, structure, lambda {|s,n,d| ['[none]',d.project.name]}
          end
        else
          ProjectDeliverable.search_secure(current_user, ProjectDeliverable.incomplete.not_closed.order("due_date ASC")).each do |d|
            level_lambda = lambda { |structure,nm,d|
              top_level = nil
              mid_level = nil
              case structure
              when 'person'
                top_level = nm
                mid_level = d.project.name
              when 'weekproject'
                top_level = dd 
                mid_level = d.project.name
              when 'weekuser'
                top_level = dd 
                mid_level = nm
              else
                top_level = d.project.name
                mid_level = nm
              end
              return [top_level,mid_level]
            }
            add_deliverable_for_index dbu, d, structure, level_lambda
          end
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

  private
  def add_deliverable_for_index dbu, d, structure, level_lambda
    h = project_deliverable_hash(d)
    nm = d.assigned_to.blank? ? '' : d.assigned_to.full_name
    dd = (d.due_date.nil?) ? 'No Due Date' : d.due_date.beginning_of_week.strftime('Week of %Y-%m-%d')
    top_level, mid_level = level_lambda.call(structure,nm,d)
    dbu[top_level] ||= {}
    dbu[top_level][mid_level] ||= []
    dbu[top_level][mid_level] << h
  end
end
