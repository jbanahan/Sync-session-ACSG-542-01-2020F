module OpenChain; module WorkflowTester; class MultiStateWorkflowTest
  def self.category; 'Actions'; end
  def self.pass? workflow_task
    mt = workflow_task.multi_state_workflow_task
    return false if mt.nil?
    return !mt.state.blank?
  end
end; end; end;