require 'open_chain/workflow_decider'
require 'open_chain/workflow_tester/attachment_type_workflow_test'
require 'open_chain/workflow_tester/multi_state_workflow_test'
require 'open_chain/workflow_tester/model_field_workflow_test'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberVendorWorkflowDecider
  extend OpenChain::WorkflowDecider
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport

  def self.base_object_class
    Company
  end

  def self.workflow_name
    'Vendor Setup'
  end

  def self.skip? company
    !company.vendor?
  end

  def self.do_workflow! vendor, workflow_inst, user
    compliance = Group.use_system_group 'LL-COMPLIANCE', "Lumber Liquidators Compliance"
    finance = Group.use_system_group 'LL-FINANCE', 'Lumber Liquidators Finance'
    # workflow_instance, task_type_code, display_rank, test_class, name, assigned_group, payload_hash
    vendor_agreement_attach = first_or_create_test! workflow_inst,
      'LL-VENDOR-AGREEMENT', 
      100, 
      OpenChain::WorkflowTester::AttachmentTypeWorkflowTest, 
      'Attach Vendor Agreement', 
      compliance, 
      {'attachment_type'=>'Vendor Agreement'}
    if vendor_agreement_attach.test!
      vendor_agreement_approve = first_or_create_test! workflow_inst,
        'LL-VEN-AGR-APPROVE',
        200,
        OpenChain::WorkflowTester::MultiStateWorkflowTest,
        'Approve Vendor Agreement',
        compliance,
        {'state_options'=>['Approve','Reject']},
        due_in_days(7)
        if vendor_agreement_approve.test! && vendor_agreement_approve.multi_state_workflow_task.state=='Approve'
          finance_approve = first_or_create_test! workflow_inst,
            'LL-FIN-APR',
            300,
            OpenChain::WorkflowTester::MultiStateWorkflowTest,
            'Approve For SAP',
            finance,
            {'state_options'=>['Approve','Reject']}
          if finance_approve.test! && finance_approve.multi_state_workflow_task.state=='Approve'
            sap_cd = prep_custom_definitions([:sap_company])[:sap_company]
            sap_num = first_or_create_test! workflow_inst,
              'LL-FIN-SAP',
              400,
              OpenChain::WorkflowTester::ModelFieldWorkflowTest,
              'Add SAP Number',
              finance,
              {'model_fields'=>[{'uid'=>sap_cd.model_field_uid}]},
              due_in_days(3)
            sap_num.test!
          end
        end
    end
    return nil
  end

  private 
  def self.due_in_days increment
    Time.use_zone('Eastern Time (US & Canada)') {return increment.days.from_now.beginning_of_day}
  end
end; end; end; end;