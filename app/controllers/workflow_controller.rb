class WorkflowController < ApplicationController
  def show
    m = CoreModule.find_by_class_name(params[:core_module],true)
    raise ActionController::RoutingError.new('Module Not Found') if m.nil?
    o = m.klass.find params[:id]
    raise ActionController::RoutingError.new("Object Not Found") unless o.can_view?(current_user)
    @base_object = o
    render layout: false
  end

  def my_tasks
    render layout: false
  end
end