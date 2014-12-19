require 'open_chain/workflow_decider'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberVendorWorkflowDecider
  extend OpenChain::WorkflowDecider

  def self.do_workflow! vendor, workflow_inst, user
    compliance = Group.use_system_group 'LL-COMPLIANCE', "Lumber Liquidators Compliance"
    vendor_agreement = workflow_inst.workflow_tasks.where(task_type_code:'LL-VENDOR-AGREEMENT').first_or_create!(
      display_rank:100,
      test_class_name:'OpenChain::WorkflowTester::AttachmentTypeWorkflowTest',
      payload_json:'{"attachment_type":"Vendor Agreement"}',
      name:'Attach Vendor Agreement',
      group_id:compliance.id
    )
    vendor_agreement.test!
    return nil
  end
end; end; end; end;