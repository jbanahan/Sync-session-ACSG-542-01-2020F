require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberVendorWorkflowDecider do
  before :each do
    @ll = Factory(:company,importer:true,system_code:'LUMBER')
    @v = Factory(:company,vendor:true)
    @u = Factory(:user)
  end

  describe :do_workflow! do
    it "should create vendor agreement task" do
      wi = Factory(:workflow_instance)
      wi.base_object = @v
      wi.save!
      described_class.do_workflow! @v, wi, @u
      wi.reload
      tasks = wi.workflow_tasks.where(
        name:'Attach Vendor Agreement',
        task_type_code:'LL-VENDOR-AGREEMENT',
        display_rank:100,
        test_class_name:'OpenChain::WorkflowTester::AttachmentTypeWorkflowTest',
        payload_json:'{"attachment_type":"Vendor Agreement"}',
        passed_at:nil
      )
      expect(tasks.count).to eq 1
      expect(tasks.first.group.system_code).to eq 'LL-COMPLIANCE'
    end
    it "should pass vendor agreement task" do
      Factory(:attachment,attachment_type:'Vendor Agreement',attachable:@v)
      @v.reload
      wi = Factory(:workflow_instance)
      wi.base_object = @v
      wi.save!
      described_class.do_workflow! @v, wi, @u
      wi.reload
      expect(wi.workflow_tasks.where(
        name:'Attach Vendor Agreement',
        task_type_code:'LL-VENDOR-AGREEMENT',
        display_rank:100,
        test_class_name:'OpenChain::WorkflowTester::AttachmentTypeWorkflowTest',
        payload_json:'{"attachment_type":"Vendor Agreement"}'
      ).first.passed?).to be_true
    end
  end
end