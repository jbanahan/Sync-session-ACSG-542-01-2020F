class WorkflowController < ApplicationController
  def show
    m = CoreModule.find_by_class_name(params[:core_module],true)
    raise ActionController::RoutingError.new('Module Not Found') if m.nil?
    o = m.klass.find params[:id]
    raise ActionController::RoutingError.new("Object Not Found") unless o.can_view?(current_user)
    @workflow_instances = o.workflow_instances
  end
end