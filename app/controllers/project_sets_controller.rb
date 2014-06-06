class ProjectSetsController < ApplicationController
  def show
    @project_set = ProjectSet.find(params[:id])
    action_secure(current_user.view_projects?, @project_set, {verb: "view", module_name: "project set"}) {
      @projects = @project_set.projects
      render 'project_sets/show'
    }
  end
end