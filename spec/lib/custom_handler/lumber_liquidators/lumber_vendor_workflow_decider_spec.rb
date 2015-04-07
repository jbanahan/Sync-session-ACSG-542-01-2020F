require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberVendorWorkflowDecider do
  def make_test passing=true
    d = double('passing-test')
    d.stub(:test!).and_return passing
    d
  end
  def build_passing_tests type_code_array
    h = Hash.new
    type_code_array.each {|c| h[c] = make_test}
    h
  end
  def run_with_tests(test_cache)
    described_class.run_with_test_cache(test_cache) do
      yield
    end
  end
  def run_with_passing_tests type_code_array
    run_with_tests(build_passing_tests(type_code_array)) do
      yield
    end
  end

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
    before :all do
      described_class.prep_custom_definitions described_class::CUSTOM_DEFINITION_INSTRUCTIONS.keys
    end

    after :all do
      CustomDefinition.destroy_all
    end
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
        run_with_passing_tests(['CMP-MERCH-VAGREE']) do
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
      end
      it "should assign merch required field for vendor agreement attachment" do
        run_with_passing_tests(['CMP-MERCH-FLDS']) do

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
      end
      it "should assign merch approval" do
        run_with_passing_tests(['CMP-MERCH-VAGREE','CMP-MERCH-FLDS']) do
          cdef = described_class.prep_custom_definitions([:cmp_merch_approved_date]).values.first

          wi = described_class.update_workflow!(@v,@u)

          tasks = wi.workflow_tasks.where(task_type_code:'CMP-MERCH-APPROVE')
          expect(tasks.size).to eq 1

          wt = tasks.first
          expect(wt.name).to eq 'Approve vendor (Merchandising)'
          expect(wt.group.system_code).to eq 'MERCH'
          expect(wt.test_class_name).to eq 'OpenChain::WorkflowTester::ModelFieldWorkflowTest'
          expect(wt.due_at).to be_nil
          expect(wt.view_path).to eq "/vendors/#{@v.id}"
          expect(wt.passed_at).to be_nil
          expect(wt.assigned_to).to be_nil
          p = wt.payload
          expect(p['model_fields']).to eq [{'uid'=>cdef.model_field_uid.to_s}]
        end
      end
      it "should not assign merch approval if no vendor agreement" do
        h = {'CMP-MERCH-VAGREE'=>make_test(false),'CMP-MERCH-FLDS'=>make_test(true)}
        run_with_tests(h) do
          wi = described_class.update_workflow!(@v,@u)
          expect(wi.workflow_tasks.find_by_task_type_code('CMP-MERCH-APPROVE')).to be_nil
        end
      end
      it "should not assign merch approval if merch fields are incomplete" do
        h = {'CMP-MERCH-VAGREE'=>make_test(true),'CMP-MERCH-FLDS'=>make_test(false)}
        run_with_tests(h) do
          wi = described_class.update_workflow!(@v,@u)
          expect(wi.workflow_tasks.find_by_task_type_code('CMP-MERCH-APPROVE')).to be_nil
        end
      end
      it "should assign legal task if deviation exists and merch approval" do
        run_with_passing_tests(['CMP-MERCH-FLDS','CMP-MERCH-APPROVE','CMP-MERCH-VAGREE']) do
          @v.attachments.create!(attachment_type:'Vendor Agreement (Deviation)')
          cdef = described_class.prep_custom_definitions([:cmp_legal_approved_date]).values.first

          wi = described_class.update_workflow!(@v,@u)

          tasks = wi.workflow_tasks.where(task_type_code:'CMP-LEGAL-APPROVE')
          expect(tasks.size).to eq 1

          wt = tasks.first
          expect(wt.name).to eq 'Approve vendor with deviation (Legal)'
          expect(wt.group.system_code).to eq 'LEGAL'
          expect(wt.test_class_name).to eq 'OpenChain::WorkflowTester::ModelFieldWorkflowTest'
          expect(wt.due_at).to be_nil
          expect(wt.view_path).to eq "/vendors/#{@v.id}"
          expect(wt.passed_at).to be_nil
          expect(wt.assigned_to).to be_nil
          p = wt.payload
          expect(p['model_fields']).to eq [{'uid'=>cdef.model_field_uid.to_s}]
        end
      end
      it "should not assign legal task if no deviation" do
        run_with_passing_tests(['CMP-MERCH-FLDS','CMP-MERCH-APPROVE','CMP-MERCH-VAGREE']) do
          @v.attachments.create!(attachment_type:'Vendor Agreement (Standard)')

          wi = described_class.update_workflow!(@v,@u)

          expect(wi.workflow_tasks.where(task_type_code:'CMP-LEGAL-APPROVE')).to be_empty
        end
      end
      it "should not assign legal task if no merch approval" do
        test_doubles = build_passing_tests(['CMP-MERCH-FLDS','CMP-MERCH-VAGREE'])
        test_doubles['CMP-MERCH-APPROVE'] = make_test(false)
        run_with_tests(test_doubles) do
          @v.attachments.create!(attachment_type:'Vendor Agreement (Deviation)')

          wi = described_class.update_workflow!(@v,@u)

          expect(wi.workflow_tasks.where(task_type_code:'CMP-LEGAL-APPROVE')).to be_empty
        end

      end
      it "should assign SAP task if legal and merch are ok" do
        run_with_passing_tests(['CMP-MERCH-FLDS','CMP-MERCH-APPROVE','CMP-MERCH-VAGREE','CMP-LEGAL-APPROVE']) do
          cdef = described_class.prep_custom_definitions([:cmp_sap_company]).values.first

          wi = described_class.update_workflow!(@v,@u)

          tasks = wi.workflow_tasks.where(task_type_code:'CMP-SAP-COMPANY')
          expect(tasks.size).to eq 1

          wt = tasks.first
          expect(wt.name).to eq 'Enter SAP Company Number'
          expect(wt.group.system_code).to eq 'SAPV'
          expect(wt.test_class_name).to eq 'OpenChain::WorkflowTester::ModelFieldWorkflowTest'
          expect(wt.due_at).to be_nil
          expect(wt.view_path).to eq "/vendors/#{@v.id}"
          expect(wt.passed_at).to be_nil
          expect(wt.assigned_to).to be_nil
          p = wt.payload
          expect(p['model_fields']).to eq [{'uid'=>cdef.model_field_uid.to_s}]
        end
      end
      it "should not assign SAP task if legal not ok" do
        @v.attachments.create!(attachment_type:'Vendor Agreement (Deviation)')
        test_doubles = build_passing_tests(['CMP-MERCH-FLDS','CMP-MERCH-VAGREE','CMP-MERCH-APPROVE'])
        test_doubles['CMP-LEGAL-APPROVE'] = make_test(false)
        run_with_tests(test_doubles) do
          wi = described_class.update_workflow!(@v,@u)

          expect(wi.workflow_tasks.where(task_type_code:'CMP-SAP-COMPANY')).to be_empty
        end
      end
      it "should not assign SAP task if merch not ok" do
        test_doubles = build_passing_tests(['CMP-MERCH-FLDS','CMP-MERCH-VAGREE','CMP-LEGAL-APPROVE'])
        test_doubles['CMP-MERCH-APPROVE'] = make_test(false)
        run_with_tests(test_doubles) do
          wi = described_class.update_workflow!(@v,@u)

          expect(wi.workflow_tasks.where(task_type_code:'CMP-SAP-COMPANY')).to be_empty
        end
      end

      it "should assign product compliance vendor agreement review if vendor agreement is attached"
      it "should assign product compliance approval after vendor agreement review and merch approved"
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
