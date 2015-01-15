class WorkflowProcessorRun < ActiveRecord::Base
  belongs_to :base_object, polymorphic: true, inverse_of: :workflow_processor_run
end
