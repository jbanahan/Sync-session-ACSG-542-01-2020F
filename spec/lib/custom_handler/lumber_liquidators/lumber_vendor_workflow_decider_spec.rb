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
    before :each do
      @wi = Factory(:workflow_instance)
      @wi.base_object = @v
      @wi.save!
    end
    it "should create vendor agreement task" do
      described_class.do_workflow! @v, @wi, @u
      @wi.reload
      tasks = @wi.workflow_tasks.where(
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
      described_class.do_workflow! @v, @wi, @u
      @wi.reload
      expect(@wi.workflow_tasks.where(
        name:'Attach Vendor Agreement',
        task_type_code:'LL-VENDOR-AGREEMENT',
        display_rank:100,
        test_class_name:'OpenChain::WorkflowTester::AttachmentTypeWorkflowTest',
        payload_json:'{"attachment_type":"Vendor Agreement"}'
      ).first.passed?).to be_true
    end
    context 'vendor agreement exists' do
      before :each do
        @wi.workflow_tasks.create!(
          name:'Attach Vendor Agreement',
          task_type_code:'LL-VENDOR-AGREEMENT',
          display_rank:100,
          test_class_name:'OpenChain::WorkflowTester::AttachmentTypeWorkflowTest',
          payload_json:'{"attachment_type":"Vendor Agreement"}',
          passed_at:1.hour.ago
        )
        @v.attachments.create(attachment_type:'Vendor Agreement')
      end
      it "should create vendor agreement approval task" do
        expect{described_class.do_workflow! @v, @wi, @u}.to change(WorkflowTask,:count).from(1).to(2)
        @wi.reload
        wt = @wi.workflow_tasks.find_by_task_type_code 'LL-VEN-AGR-APPROVE'
        expect(wt.name).to eq 'Approve Vendor Agreement'
        expect(wt.test_class_name).to eq 'OpenChain::WorkflowTester::MultiStateWorkflowTest'
        expect(wt.payload_json).to eq '{"state_options":["Approve","Reject"]}'
        expect(wt.due_at > 5.days.from_now).to be_true
      end
      context 'vendor agrement approved' do
        before :each do
          @wi.workflow_tasks.create!(
            name:'Approve Vendor Agreement',
            task_type_code:'LL-VEN-AGR-APPROVE',
            display_rank:200,
            test_class_name:'OpenChain::WorkflowTester::MultiStateWorkflowTest',
            payload_json:'{"state_options":["Approve","Reject"]}',
            passed_at:1.hour.ago
          ).create_multi_state_workflow_task!(state:'Approve')
        end
        it "should create finance approval" do
          expect{described_class.do_workflow! @v, @wi, @u}.to change(WorkflowTask,:count).from(2).to(3)
          @wi.reload
          wt = @wi.workflow_tasks.find_by_task_type_code 'LL-FIN-APR'
          expect(wt.name).to eq 'Approve For SAP'
          expect(wt.test_class_name).to eq 'OpenChain::WorkflowTester::MultiStateWorkflowTest'
          expect(wt.payload_json).to eq '{"state_options":["Approve","Reject"]}'
          expect(wt.group.system_code).to eq 'LL-FINANCE'
        end
        context 'finance approved' do
          before :each do
            wt = @wi.workflow_tasks.create!(
              name:'Approve For SAP',
              task_type_code:'LL-FIN-APR',
              display_rank:300,
              test_class_name:'OpenChain::WorkflowTester::MultiStateWorkflowTest',
              payload_json:'{"state_options":["Approve","Reject"]}',
              passed_at:1.hour.ago
            )
            wt.create_multi_state_workflow_task!(state:'Approve')
          end
          it "should create SAP number data requirement" do
            cdefs = described_class.prep_custom_definitions [:sap_company]
            expect{described_class.do_workflow! @v, @wi, @u}.to change(WorkflowTask,:count).from(3).to(4)
            @wi.reload
            wt = @wi.workflow_tasks.find_by_task_type_code 'LL-FIN-SAP'
            expect(wt.name).to eq 'Add SAP Number'
            expect(wt.test_class_name).to eq 'OpenChain::WorkflowTester::ModelFieldWorkflowTest'
            expected_payload = {'model_fields'=>[{'uid'=>cdefs[:sap_company].model_field_uid}]}.to_json
            expect(wt.payload_json).to eq expected_payload
            expect(wt.group.system_code).to eq 'LL-FINANCE'
            expect(wt).to_not be_passed
          end
        end
      end
    end
  end
end