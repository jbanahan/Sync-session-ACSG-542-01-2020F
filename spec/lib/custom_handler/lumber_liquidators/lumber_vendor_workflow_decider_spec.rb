require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberVendorWorkflowDecider do
  before :each do
    @ll = Factory(:company,importer:true,system_code:'LUMBER')
    @v = Factory(:company,vendor:true)
    @u = Factory(:user)
  end

  describe :workflow_name do
    it "should return Vendor Setup" do
      expect(described_class.workflow_name).to eq 'Vendor Setup'
    end
  end
  describe :skip? do
    it "should skip non-vendor" do
      expect(described_class.skip?(@ll)).to be_true
      expect(described_class.skip?(@v)).to be_false
      expect{described_class.update_workflow!(@ll,@u)}.to_not change(WorkflowInstance,:count)
    end
  end

  describe :do_workflow! do
    context 'locked' do
      it "should delete all open tasks if locked" do
        wi = nil
        #create tasks
        expect{wi = described_class.update_workflow!(@v,@u)}.to change(WorkflowTask,:count)

        #add passed workflow item which should be ignored
        wt = Factory(:workflow_task,workflow_instance:wi,passed_at:1.second.ago)

        #lock the vendor
        @v.stub(:locked?).and_return true

        #delete non passed tasks for locked vendor

        expect{described_class.update_workflow!(@v,@u)}.to change(WorkflowTask,:count).to(1)
        expect(WorkflowTask.first).to eq wt #keep the passed ones
      end
    end
    context 'vendor level' do
      it "should assign merch required fields" do
        wi = described_class.update_workflow!(@v,@u)



        tasks = wi.workflow_tasks.where(task_type_code:'CMP-MERCH-FLDS')
        expect(tasks.size).to eq 1

        wt = tasks.first
        expect(wt.name).to eq 'Enter required merchandising fields'
        expect(wt.group.system_code).to eq 'MERCH'
        expect(wt.test_class_name).to eq 'OpenChain::WorkflowTester::ModelFieldWorkflowTest'
        expect(wt.due_at).to be_nil
        expect(wt.view_path).to eq "/vendors/#{@v.id}"
        expect(wt.passed_at).to be_nil
        expect(wt.assigned_to).to be_nil

        #make sure at least one of the required model fields are in the payload
        p = wt.payload
        cdef = described_class.prep_custom_definitions([:cmp_requested_payment_method]).values.first
        expect(p['model_fields'].index{|mf| mf['uid']==cdef.model_field_uid.to_s}).to_not be_nil
      end
      it "should assign merch required field for vendor agreement attachment" do
        wi = described_class.update_workflow!(@v,@u)

        tasks = wi.workflow_tasks.where(task_type_code:'CMP-MERCH-VAGREE')
        expect(tasks.size).to eq 1

        wt = tasks.first
        expect(wt.name).to eq 'Attach Vendor Agreement'
        expect(wt.group.system_code).to eq 'MERCH'
        expect(wt.test_class_name).to eq 'OpenChain::WorkflowTester::ModelFieldWorkflowTest'
        expect(wt.due_at).to be_nil
        expect(wt.view_path).to eq "/vendors/#{@v.id}"
        expect(wt.passed_at).to be_nil
        expect(wt.assigned_to).to be_nil
        p = wt.payload
        attachment_types_model_field_setup = p['model_fields'].find{|mf| mf['uid']=='cmp_attachment_types'}
        expect(attachment_types_model_field_setup['regex']).to eq 'Vendor Agreement'

      end
      it "should assign merch approval"
      it "should assign legal task if deviation exists and merch approval"
      it "should assign PC required fields" #confirm this against the matrix
      it "should assign PC approval after merch approval"
      it "should assign PC Exec approval after PC Approval"
    end
    context 'plant level' do
      it "should assign merch required fields"
      it "should assign merch approval"
      it "should assign PC approval after merch approval"
      it "should assign PC Exec approval after PC Approval"
      it "should assign MID required to TC"
      it "should assign TC approval after merch approval and TC fields"
    end
    context 'plant / product group level' do
      it "should assign merch fields"
      it "should assign QA required fields"
      it "should assign QA approval"
      it "should assign PC required fields"
      it "should assign PC approval"
      it "should assign PC Exec approval after PC Approval"
    end
  end
end
