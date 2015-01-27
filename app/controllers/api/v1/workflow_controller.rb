require 'open_chain/workflow_processor'
module Api; module V1; class WorkflowController < Api::V1::ApiController
  before_filter :secure_task, only: [:assign, :set_multi_state]
  def assign
    assignment_user = nil
    if !params[:user_id].blank?
      assignment_user = User.find params[:user_id]
      raise StatusableError.new("User cannot be assigned to task without edit permission.",400) unless @wt.can_edit?(assignment_user)
    end
    @wt.assigned_to = assignment_user
    save_state = @wt.save
    raise StatusableError.new(@wt.errors.full_messages.join("\n")) unless save_state
    render json:{'user_id'=>(assignment_user.blank? ? nil : assignment_user.id)}
  end

  def set_multi_state 
    raise StatusableError.new("Options #{params[:state]} is not a valid choice.",400) unless @wt.payload['state_options'].include? params[:state]
    m = @wt.multi_state_workflow_task
    m = @wt.create_multi_state_workflow_task if m.nil?
    m.update_attributes(state:params[:state])
    OpenChain::WorkflowProcessor.new.process! @wt.workflow_instance.base_object, current_user
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

  private
  def secure_task
    @wt = WorkflowTask.find params[:id]
    raise StatusableError.new("You do not have permission to edit this task",401) unless @wt.can_edit?(current_user)
  end
end; end; end