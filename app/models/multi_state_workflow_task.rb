class MultiStateWorkflowTask < ActiveRecord::Base
  belongs_to :workflow_task, touch: true, inverse_of: :multi_state_workflow_task
end
