require 'spec_helper'

describe WorkflowInstance do
  describe :destroy_stale_tasks do
    it "should destroy tasks that are not in the tasks_to_keep list and are in the types_to_destroy list" do
      c = Factory(:company)
      wi = Factory(:workflow_instance, base_object: c)

      #keep this one because it's in the tasks to keep list
      wt1 = Factory(:workflow_task, workflow_instance: wi, task_type_code:'A')

      #destroy this one
      wt2 = Factory(:workflow_task, workflow_instance: wi, task_type_code:'A')

      #keep this one because it's not in the types to destroy list
      wt3 = Factory(:workflow_task, workflow_instance: wi, task_type_code:'B')

      tasks_to_keep = [wt1]
      types_to_destroy = ['A']

      wi.destroy_stale_tasks(tasks_to_keep,types_to_destroy)

      expect(wi.workflow_tasks.order(:id).to_a).to eq [wt1,wt3]
    end
  end  
end
