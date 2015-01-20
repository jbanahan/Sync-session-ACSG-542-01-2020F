require 'open_chain/workflow_decider'
require 'open_chain/workflow_tester/multi_state_workflow_test'
require 'open_chain/custom_handler/j_jill/j_jill_support'

module OpenChain; module CustomHandler; module JJill; class JJillBookingApprovalDecider
  extend OpenChain::WorkflowDecider
  include OpenChain::CustomHandler::JJill::JJillSupport

  def self.base_object_class
    Shipment
  end

  def self.workflow_name
    'J Jill Booking Approval'
  end

  def self.skip? shipment
    return true unless shipment.importer
    return shipment.importer.system_code!=UID_PREFIX
  end

  def self.do_workflow! shipment, workflow_inst, user
    lmd = Group.use_system_group 'VFI-LMD-BOOK', "LMD Booking Team"
    approvers = Group.use_system_group 'JJILL-BOOK-APRV', "J Jill Booking Approvers"
    book_req = first_or_create_test! workflow_inst,
      'JJILL-BOOKREQ',
      100,
      OpenChain::WorkflowTester::MultiStateWorkflowTest,
      'Request Booking Approval',
      lmd,
      {'state_options'=>['Request','Cancel']},
      due_in_days(3)
    if book_req.test! && book_req.multi_state_workflow_task.state=='Request'
      book_approval = first_or_create_test! workflow_inst,
        'JJILL-BOOK-APRV',
        200,
        OpenChain::WorkflowTester::MultiStateWorkflowTest,
        'Approve Booking',
        approvers,
        {'state_options'=>['Approve','Cancel']}
      book_approval.test!
    end
    return nil
  end

  private 
  def self.due_in_days increment
    Time.use_zone('Eastern Time (US & Canada)') {return increment.days.from_now.beginning_of_day}
  end
end; end; end; end;