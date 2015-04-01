require 'open_chain/workflow_decider'
require 'open_chain/workflow_tester/attachment_type_workflow_test'
require 'open_chain/workflow_tester/multi_state_workflow_test'
require 'open_chain/workflow_tester/model_field_workflow_test'
require 'open_chain/workflow_tester/survey_complete_workflow_test'
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
    # cdefs = prep_custom_definitions([:ven_tc_approved_date])
    # trade_compliance = Group.use_system_group 'LL-TRADE-COMP', 'Trade Compliance'
    # tc_approval = first_or_create_test! workflow_inst,
    #   'LL-TC-APRV',
    #   OpenChain::WorkflowTester::ModelFieldWorkflowTest,
    #   'Approve vendor for trade compliance',
    #   trade_compliance,
    #   {'model_fields'=>[{'uid'=>cdefs[:ven_tc_approved_date].model_field_uid}]},
    #   nil,
    #   view_path(vendor)
    # tc_approval.test!
    return nil
  end

  private
  def self.due_in_days increment
    Time.use_zone('Eastern Time (US & Canada)') {return increment.days.from_now.beginning_of_day}
  end

  def self.view_path base_object
    "/vendors/#{base_object.id}"
  end
end; end; end; end;
