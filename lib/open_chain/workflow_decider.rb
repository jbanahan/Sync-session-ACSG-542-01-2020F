# Adds key workflow decider methods including the public
# update_workflow!(obj,user) method
#
# Expects concrete classes to implement self.do_workflow!(base_object,workflow_instance,user)
module OpenChain; module WorkflowDecider

  def update_workflow! base_object, user
    Lock.acquire("Workflow-#{base_object.class.to_s}-#{base_object.id}",temp_lock:true) do
      ActiveRecord::Base.transaction do
        w = base_object.workflow_instances.where(workflow_decider_class:self.name).first_or_create!
        do_workflow!(base_object,w,user)
        return w
      end
    end
  end

end; end;