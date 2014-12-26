# Adds key workflow decider methods including the public
# update_workflow!(obj,user) method
#
# Expects concrete classes to implement self.do_workflow!(base_object,workflow_instance,user)
#
# Expects concrete classes to implement self.name method returning descrptive name of the workflow
module OpenChain; module WorkflowDecider

  def update_workflow! base_object, user
    Lock.acquire("Workflow-#{base_object.class.to_s}-#{base_object.id}",temp_lock:true) do
      ActiveRecord::Base.transaction do
        w = base_object.workflow_instances.where(workflow_decider_class:self.name).first_or_create!(name:self.workflow_name)
        do_workflow!(base_object,w,user)
        return w
      end
    end
  end

  def first_or_create_test! workflow_instance, task_type_code, display_rank, test_class, name, assigned_group, payload_hash
    workflow_instance.workflow_tasks.where(task_type_code:task_type_code).first_or_create!(
      display_rank:display_rank,
      test_class_name:test_class.name,
      payload_json:payload_hash.to_json,
      name:name,
      group_id:assigned_group.id
    )
  end

end; end;