module OpenChain; module CustomHandler; module JJill; class JJillOrderApprovalWorkflowDecider
  def self.base_object_class
    Order
  end
  def self.workflow_name
    'Order Approval'
  end
  def self.do_workflow! order, workflow_inst, user
  end
end; end; end; end;