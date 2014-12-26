module Api; module V1; class WorkflowController < Api::V1::ApiController
  def set_multi_state 
    wt = WorkflowTask.find params[:id]
    raise StatusableError.new("You do not have permission to edit this task",401) unless wt.can_edit?(current_user)
    raise StatusableError.new("Options #{params[:state]} is not a valid choice.",400) unless wt.payload['state_options'].include? params[:state]
    m = wt.multi_state_workflow_task
    m = wt.create_multi_state_workflow_task if m.nil?
    m.update_attributes(state:params[:state])
    render json:{state:m.state}
  end

  def my_instance_open_task_count
    m = CoreModule.find_by_class_name(params[:core_module],true)
    raise StatusableError.new('Module Not Found',404) if m.nil?
    o = m.klass.find params[:id]
    raise StatusableError.new("Object Not Found",404) unless o.can_view?(current_user)
    qry = WorkflowTask.for_user(current_user).not_passed.for_base_object(o)
    count = qry.count
    render json: {'count'=>count}
  end
end; end; end