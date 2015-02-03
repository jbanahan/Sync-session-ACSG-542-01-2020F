require "spec_helper"

describe OpenChain::CustomHandler::JJill::JJillBookingApprovalDecider do
  describe :skip? do
    it "should not skip J Jill shipments" do
      imp = Factory(:company,system_code:'JJILL')
      s = Factory(:shipment,importer:imp)
      expect(described_class.skip?(s)).to be_false
    end
    it "should skip non-J Jill shipments" do
      imp = Factory(:company)
      s = Factory(:shipment,importer:imp)
      expect(described_class.skip?(s)).to be_true
    end
  end

  describe :do_workflow! do
    before :each do
      imp = Factory(:company,system_code:'JJILL')
      @s = Factory(:shipment,importer:imp)
      @wi = Factory(:workflow_instance)
      @wi.base_object = @s
      @wi.save!
      @u = Factory(:user)
    end
    it "should create request booking task" do
      expect{described_class.do_workflow!(@s,@wi,@u)}.to change(WorkflowTask,:count).from(0).to(1)
      @wi.reload
      tasks = @wi.workflow_tasks.where(
        name:'Request Booking Approval',
        task_type_code:'JJILL-BOOKREQ',
        test_class_name:'OpenChain::WorkflowTester::MultiStateWorkflowTest',
        payload_json:'{"state_options":["Request","Cancel"]}',
        passed_at:nil
      )
      expect(tasks.count).to eq 1
    end
    context "booking requested" do
      before :each do
        wt = @wi.workflow_tasks.where(
          name:'Request Booking Approval',
          task_type_code:'JJILL-BOOKREQ',
          test_class_name:'OpenChain::WorkflowTester::MultiStateWorkflowTest',
          payload_json:'{"state_options":["Request","Cancel"]}',
          passed_at:nil
        ).first_or_create!
        wt.create_multi_state_workflow_task!(state:'Request')
      end
      it "should create approve booking task" do
        expect{described_class.do_workflow!(@s,@wi,@u)}.to change(WorkflowTask,:count).from(1).to(2)
        @wi.reload
        tasks = @wi.workflow_tasks.where(
          name:'Approve Booking',
          task_type_code:'JJILL-BOOK-APRV',
          test_class_name:'OpenChain::WorkflowTester::MultiStateWorkflowTest',
          payload_json:'{"state_options":["Approve","Cancel"]}',
          passed_at:nil
        )
        expect(tasks.count).to eq 1 
      end
    end
  end
end