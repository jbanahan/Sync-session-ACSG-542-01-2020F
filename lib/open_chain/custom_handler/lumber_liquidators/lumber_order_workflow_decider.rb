module OpenChain; module CustomHandler; module LumberLiquidators; class LumberOrderWorkflowDecider
  extend OpenChain::WorkflowDecider
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  def self.base_object_class
    Order
  end
  def self.workflow_name
    "Order Workflow"
  end

  def self.do_workflow! order, workflow_inst, user
  end
end; end; end; end;