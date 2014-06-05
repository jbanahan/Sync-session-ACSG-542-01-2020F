class ProjectSetsController < ApplicationController
  def show
    if !current_user.view_projects?
      error_redirect "You do not have permission to view projects"
      return
    end
    @project_set = ProjectSet.find(params[:id])
    @projects = @project_set.projects
  end
end