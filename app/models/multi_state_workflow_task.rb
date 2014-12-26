class MultiStateWorkflowTask < ActiveRecord::Base
  belongs_to :workflow_task, touch: true, inverse_of: :multi_state_workflow_task

  def options
    opt_list = self.state_options_list
    opt_list = "" if opt_list.blank?
    opt_list.split("\n")
  end

  def options= option_array
    self.state_options_list = option_array.join("\n")
  end
end
