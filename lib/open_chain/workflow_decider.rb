# Adds key workflow decider methods including the public
# update_workflow!(obj,user) method
#
# Expects concrete classes to implement self.do_workflow!(base_object,workflow_instance,user)
#
# Expects concrete classes to implement self.name method returning descriptive name of the workflow
#
# Expects concrete classes to implement self.base_object_class returning the class that matches the expected base_object for `update_workflow!`
#
# Concrete class can implement `skip?(base_object)` and return true to avoid creating workflow instances for irrelevant objects
module OpenChain; module WorkflowDecider

  def update_workflow! base_object, user
    Lock.acquire("Workflow-#{base_object.class.to_s}-#{base_object.id}",temp_lock:true) do
      ActiveRecord::Base.transaction do
        if !skip?(base_object)
          w = base_object.workflow_instances.where(workflow_decider_class:self.name).first_or_create!(name:self.workflow_name)
          do_workflow!(base_object,w,user)
          return w
        end
      end
    end
  end

  def first_or_create_test! workflow_instance, task_type_code,  test_class, name, assigned_group, payload_hash, due_at=nil, view_path=nil
    inst = @@test_cache[task_type_code] if defined?(@@test_cache)
    return inst if inst

    workflow_instance.workflow_tasks.where(task_type_code:task_type_code).first_or_create!(
      test_class_name:test_class.name,
      payload_json:payload_hash.to_json,
      name:name,
      group_id:assigned_group.id,
      due_at:due_at,
      view_path: view_path
    )
  end

  # convenience method for first_or_create_test! with AttachmentTypeWorkflowTest
  #
  # method also makes sure the requested attachment type is in the AttachmentType table
  def first_or_create_attachment_test! attachment_type_name, workflow_instance, task_type_code, name, assigned_group, due_at=nil, view_path=nil
    AttachmentType.transaction do
      AttachmentType.where(name:attachment_type_name).first_or_create!
      first_or_create_test! workflow_instance,
        task_type_code,
        OpenChain::WorkflowTester::AttachmentTypeWorkflowTest,
        name,
        assigned_group,
        {'attachment_type'=>attachment_type_name},
        due_at,
        view_path
    end
  end

  #override to skip objects in `update_workflow!`
  def skip? base_object
    false
  end

  #sets a cache of WorkflowTests keyed by task_type_code
  #that will be returned by first_or_create_test! instead of hitting
  #the database.  Helpful for test stubbing/performance.
  def run_with_test_cache(test_cache_hash)
    begin
      @@test_cache = test_cache_hash
      yield
    ensure
      @@test_cache = {}
    end
  end

end; end;
