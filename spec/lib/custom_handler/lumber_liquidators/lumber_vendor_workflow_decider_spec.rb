require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberVendorWorkflowDecider do
  def validate_task_assigned passing_tests, task_type_code, expected_vals
    @passing_tests_base ||= []
    @passing_tests_base += passing_tests
    run_with_passing_tests(@passing_tests_base) do
      wi = described_class.update_workflow!(@v,@u)

      tasks = wi.workflow_tasks.where(task_type_code:task_type_code)
      expect(tasks.size).to eq 1

      wt = tasks.first
      expect(wt.name).to eq expected_vals[:name]
      expect(wt.group.system_code).to eq expected_vals[:group_code]
      expect(wt.test_class_name).to eq expected_vals[:class_name]
      expect(wt.due_at).to eq expected_vals[:due_at]
      expect(wt.view_path).to eq expected_vals[:view_path]
      expect(wt.passed_at).to eq expected_vals[:passed_at]
      expect(wt.assigned_to).to eq expected_vals[:assigned_to]
      expect(wt.target_object).to eq expected_vals[:target_object]

      yield wt if block_given?
    end
  end
  def validate_model_field_payload workflow_task, custom_def_ids
    p = workflow_task.payload
    cdefs = described_class.prep_custom_definitions(custom_def_ids)
    custom_def_ids.each do |cd_id|
      expect(p['model_fields'].index{|mf| mf['uid']==cdefs[cd_id].model_field_uid.to_s}).to_not be_nil
    end
  end
  def make_test task_type_code, passing=true
    @make_test_stub_id ||= 999999
    d = double('passing-test')
    d.stub(:test!).and_return passing
    d.stub(:task_type_code).and_return task_type_code
    d.stub(:id).and_return(@make_test_stub_id)
    @make_test_stub_id += 1
    d
  end
  def build_passing_tests type_code_array
    h = Hash.new
    type_code_array.each {|c| h[c] = make_test(c)}
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
    @wftest = 'OpenChain::WorkflowTester::ModelFieldWorkflowTest'
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
      before :each do
        @view_path = "/vendors/#{@v.id}"
      end

      it "should assign merch required fields" do
        expected_vals = {
          name:'Enter required merchandising fields',
          group_code:'MERCH',
          class_name: @wftest,
          view_path:@view_path
        }
        validate_task_assigned(['CMP-MERCH-VAGREE'], 'CMP-MERCH-FLDS', expected_vals) do |wt|
          #make sure at least one of the required model fields are in the payload
          validate_model_field_payload(wt,[:cmp_requested_payment_method])
        end
      end

      it "should assign merch required field for vendor agreement attachment" do
        expected_vals = {
          name:'Attach Vendor Agreement',
          group_code:'MERCH',
          class_name:@wftest,
          view_path:@view_path
        }
        validate_task_assigned(['CMP-MERCH-FLDS'], 'CMP-MERCH-VAGREE', expected_vals) do |wt|
          p = wt.payload
          attachment_types_model_field_setup = p['model_fields'].find{|mf| mf['uid']=='cmp_attachment_types'}
          expect(attachment_types_model_field_setup['regex']).to eq 'Vendor Agreement'
        end
      end

      it "should assign merch approval" do
        expected_vals = {
          name:'Approve vendor (Merchandising)',
          group_code:'MERCH',
          class_name:@wftest,
          view_path:@view_path
        }
        validate_task_assigned(['CMP-MERCH-VAGREE','CMP-MERCH-FLDS'],'CMP-MERCH-APPROVE',expected_vals) do |wt|
          validate_model_field_payload(wt,[:cmp_merch_approved_date])
        end
      end

      it "should not assign merch approval if no vendor agreement" do
        h = {'CMP-MERCH-VAGREE'=>make_test('CMP-MERCH-VAGREE',false),'CMP-MERCH-FLDS'=>make_test('CMP-MERCH-FLDS',true)}
        run_with_tests(h) do
          wi = described_class.update_workflow!(@v,@u)
          expect(wi.workflow_tasks.find_by_task_type_code('CMP-MERCH-APPROVE')).to be_nil
        end
      end

      it "should not assign merch approval if merch fields are incomplete" do
        h = {'CMP-MERCH-VAGREE'=>make_test('CMP-MERCH-VAGREE',true),'CMP-MERCH-FLDS'=>make_test('CMP-MERCH-FLDS',false)}
        run_with_tests(h) do
          wi = described_class.update_workflow!(@v,@u)
          expect(wi.workflow_tasks.find_by_task_type_code('CMP-MERCH-APPROVE')).to be_nil
        end
      end

      it "should assign legal task if deviation exists and merch approval" do
        @v.attachments.create!(attachment_type:'Vendor Agreement (Deviation)')
        expected_vals = {
          name:'Approve vendor with deviation (Legal)',
          group_code:'LEGAL',
          class_name:@wftest,
          view_path:@view_path
        }
        validate_task_assigned(['CMP-MERCH-FLDS','CMP-MERCH-APPROVE','CMP-MERCH-VAGREE'],'CMP-LEGAL-APPROVE',expected_vals) do |wt|
          validate_model_field_payload(wt,[:cmp_legal_approved_date])
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
        test_doubles['CMP-MERCH-APPROVE'] = make_test('CMP-MERCH-APPROVE',false)
        run_with_tests(test_doubles) do
          @v.attachments.create!(attachment_type:'Vendor Agreement (Deviation)')

          wi = described_class.update_workflow!(@v,@u)

          expect(wi.workflow_tasks.where(task_type_code:'CMP-LEGAL-APPROVE')).to be_empty
        end
      end

      it "should assign SAP task if legal and merch are ok" do
        expected_vals = {
          name: 'Enter SAP Company Number',
          group_code: 'SAPV',
          class_name: @wftest,
          view_path: @view_path
        }
        passed_tests = ['CMP-MERCH-FLDS','CMP-MERCH-APPROVE','CMP-MERCH-VAGREE','CMP-LEGAL-APPROVE']
        validate_task_assigned(passed_tests,'CMP-SAP-COMPANY',expected_vals) do |wt|
          validate_model_field_payload(wt,[:cmp_sap_company])
        end
      end
      it "should not assign SAP task if legal not ok" do
        @v.attachments.create!(attachment_type:'Vendor Agreement (Deviation)')
        test_doubles = build_passing_tests(['CMP-MERCH-FLDS','CMP-MERCH-VAGREE','CMP-MERCH-APPROVE'])
        test_doubles['CMP-LEGAL-APPROVE'] = make_test('CMP-LEGAL-APPROVE',false)
        run_with_tests(test_doubles) do
          wi = described_class.update_workflow!(@v,@u)

          expect(wi.workflow_tasks.where(task_type_code:'CMP-SAP-COMPANY')).to be_empty
        end
      end
      it "should not assign SAP task if merch not ok" do
        test_doubles = build_passing_tests(['CMP-MERCH-FLDS','CMP-MERCH-VAGREE','CMP-LEGAL-APPROVE'])
        test_doubles['CMP-MERCH-APPROVE'] = make_test('CMP-MERCH-APPROVE',false)
        run_with_tests(test_doubles) do
          wi = described_class.update_workflow!(@v,@u)

          expect(wi.workflow_tasks.where(task_type_code:'CMP-SAP-COMPANY')).to be_empty
        end
      end

      it "should assign product compliance vendor agreement review if vendor agreement is attached and merchandising approved" do
        # at the time of writing we shouldn't have to test for vendor agreement
        # being attached since you can't CMP-MERCH-APPROVE without it, but we're
        # going to check anyway since the rules should be decoupled
        @v.attachments.create!(attachment_type:'Vendor Agreement (Standard)')
        passing_tests = ['CMP-MERCH-FLDS','CMP-MERCH-VAGREE','CMP-MERCH-APPROVE']
        expected_vals = {
          name: 'Approve vendor agreement for Product Compliance',
          group_code: 'PRODUCTCOMP',
          class_name: @wftest,
          view_path: @view_path
        }

        validate_task_assigned(passing_tests,'CMP-PC-VAGREE',expected_vals) do |wt|
          validate_model_field_payload(wt,[:cmp_vendor_agreement_review])
        end      
      end

      it "should assign product compliance approval after vendor agreement re view and merch approved" do
        @v.attachments.create!(attachment_type:'Vendor Agreement (Standard)')
        passing_tests = ['CMP-MERCH-FLDS','CMP-MERCH-VAGREE','CMP-MERCH-APPROVE','CMP-PC-VAGREE']
        expected_vals = {
          name: 'Approve vendor (Product Compliance)',
          group_code: 'PRODUCTCOMP',
          class_name: @wftest,
          view_path: @view_path
        }

        validate_task_assigned(passing_tests,'CMP-PC-APPROVE',expected_vals) do |wt|
          validate_model_field_payload(wt,[:cmp_pc_approved_date])
        end
      end
    end
    context 'plant level' do
      before(:each) do
        @plant = Factory(:plant,company:@v,name:'plantname')
        @passing_tests_base = ['CMP-MERCH-VAGREE','CMP-MERCH-FLDS'] #avoid building company lavel tasks
        @plant_view_path = "/vendors/#{@v.id}/vendor_plants/#{@plant.id}"
      end

      it "should assign merch required fields" do
        expected_vals = {
          name: "Enter required merchandising fields (Plant: #{@plant.name})",
          group_code: 'MERCH',
          class_name: @wftest,
          view_path: @plant_view_path,
          target_object: @plant
        }
        validate_task_assigned(@passing_tests_base,'PLNT-MERCH-FLDS',expected_vals) do |wt|
          #make sure at least one of the required model fields are in the payload
          validate_model_field_payload(wt,[:plnt_sap_coo_abbreviation])
        end
      end

      it "should assign merch approval" do
        @passing_tests_base << 'PLNT-MERCH-FLDS'
        expected_vals = {
          name: "Approve plant (Merchandising) (Plant: #{@plant.name})",
          group_code: 'MERCH',
          class_name: @wftest,
          view_path: @plant_view_path,
          target_object: @plant
        }
        validate_task_assigned(@passing_tests_base,'PLNT-MERCH-APPROVE',expected_vals) do |wt|
          #make sure at least one of the required model fields are in the payload
          validate_model_field_payload(wt,[:plnt_merch_approved_date])
        end
      end

      it "should require triage document review" do
        @passing_tests_base += ['PLNT-MERCH-FLDS','PLNT-MERCH-APPROVE']
        expected_vals = {
          name: "Update Triage Document Review (Plant: #{@plant.name})",
          group_code: 'PRODUCTCOMP',
          class_name: @wftest,
          view_path: @plant_view_path,
          target_object: @plant
        }
        validate_task_assigned(@passing_tests_base,'PLNT-TRIAGE-REVIEW',expected_vals) do |wt|
          validate_model_field_payload(wt,[:plnt_triage_document_review])
        end
      end
      it "should assign PC approval after merch approval" do
        @passing_tests_base += ['PLNT-MERCH-FLDS','PLNT-MERCH-APPROVE','PLNT-TRIAGE-REVIEW']
        expected_vals = {
          name: "Approve Plant (Product Compliance) (Plant: #{@plant.name})",
          group_code: 'PRODUCTCOMP',
          class_name: @wftest,
          view_path: @plant_view_path,
          target_object: @plant
        }
        validate_task_assigned(@passing_tests_base,'PLNT-PC-APPROVE',expected_vals) do |wt|
          validate_model_field_payload(wt,[:plnt_pc_approved_date])
        end
      end
      it "should assign PC Exec triage review" do
        @passing_tests_base += ['PLNT-MERCH-FLDS','PLNT-MERCH-APPROVE','PLNT-TRIAGE-REVIEW','PLNT-PC-APPROVE']
        expected_vals = {
          name: "Update Triage Document Exec Review (Plant: #{@plant.name})",
          group_code: 'EXPRODUCTCOMP',
          class_name: @wftest,
          view_path: @plant_view_path,
          target_object: @plant
        }
        validate_task_assigned(@passing_tests_base,'PLNT-PCE-TRIAGE',expected_vals) do |wt|
          validate_model_field_payload(wt,[:plnt_triage_exec_review])
        end
      end
      it "should assign PC Exec approval after exec triage review" do
        @passing_tests_base += ['PLNT-MERCH-FLDS','PLNT-MERCH-APPROVE','PLNT-TRIAGE-REVIEW','PLNT-PC-APPROVE','PLNT-PCE-TRIAGE']
        expected_vals = {
          name: "Approve Plant (Prod Compliance Exec) (Plant: #{@plant.name})",
          group_code: 'EXPRODUCTCOMP',
          class_name: @wftest,
          view_path: @plant_view_path,
          target_object: @plant
        }
        validate_task_assigned(@passing_tests_base,'PLNT-PCE-APPROVE',expected_vals) do |wt|
          validate_model_field_payload(wt,[:plnt_pc_approved_date_executive])
        end
      end

      it "should not assign TC tasks if there aren't product groups assigned" do
        @passing_tests_base += ['PLNT-MERCH-FLDS','PLNT-MERCH-APPROVE']
        run_with_passing_tests(@passing_tests_base) do
          wi = described_class.update_workflow!(@v,@u)
          expect(wi.workflow_tasks.find_by_task_type_code('PLNT-TC-FLDS')).to be_nil
        end
      end

      context :trade_compliance do
        before :each do 
          @plant.product_groups << Factory(:product_group,name:'XX')
        end
        it "should assign MID required to TC when merch approved and there are product groups assigned" do
          @passing_tests_base += ['PLNT-MERCH-FLDS','PLNT-MERCH-APPROVE']
          expected_vals = {
            name: "Add MID (Plant: #{@plant.name})",
            group_code: 'TRADECOMP',
            class_name: @wftest,
            view_path: @plant_view_path,
            target_object: @plant
          }
          validate_task_assigned(@passing_tests_base,'PLNT-TC-FLDS',expected_vals) do |wt|
            validate_model_field_payload(wt,[:plnt_mid_code])
          end
        end
        it "should assign TC approval after merch approval and TC fields" do
          @passing_tests_base += ['PLNT-MERCH-FLDS','PLNT-MERCH-APPROVE','PLNT-TC-FLDS']
          expected_vals = {
            name: "Approve Plant (Trade Comp) (Plant: #{@plant.name})",
            group_code: 'TRADECOMP',
            class_name: @wftest,
            view_path: @plant_view_path,
            target_object: @plant
          }
          validate_task_assigned(@passing_tests_base,'PLNT-TC-APPROVE',expected_vals) do |wt|
            validate_model_field_payload(wt,[:plnt_tc_approved_date])
          end
        end
      end
      it "should run for multiple plants" do
        @plant2 = Factory(:plant,company:@v,name:'plantname2')
        run_with_passing_tests(@passing_tests_base) do
          wi = described_class.update_workflow!(@v,@u)
          tasks = wi.workflow_tasks.where(task_type_code:'PLNT-MERCH-FLDS')
          expect(tasks.size).to eq 2
        end
      end
      context 'plant / product group level' do
        before :each do
          @product_group = Factory(:product_group,name:'pgn')
          @ppga = @plant.plant_product_group_assignments.create!(product_group_id:@product_group.id)
          @ppga_view_path = "/vendors/#{@v.id}/vendor_plants/#{@plant.id}/plant_product_group_assignments/#{@ppga.id}"
          @passing_tests_base += ['PLNT-MERCH-FLDS','PLNT-MERCH-APPROVE','PLNT-PC-APPROVE','PLNT-TRIAGE-REVIEW','PLNT-PCE-TRIAGE','PLNT-PCE-APPROVE'] #skip plant tests
        end
        it "should assign merch approval" do
          expected_vals = {
            name: "Approve plant #{@plant.name} for product group #{@product_group.name}",
            group_code: 'MERCH',
            class_name: @wftest,
            view_path: @ppga_view_path,
            target_object: @ppga
          }
          validate_task_assigned(@passing_tests_base,'PPGA-MERCH-APPROVE',expected_vals) do |wt|
            validate_model_field_payload(wt,[:ppga_merch_approved_date])
          end
        end
        it "should assign QA required fields" do
          @passing_tests_base << 'PPGA-MERCH-APPROVE'
          expected_vals = {
            name: "Enter required QA fields (#{@plant.name}/#{@product_group.name})",
            group_code: 'QUALITY',
            class_name: @wftest,
            view_path: @ppga_view_path,
            target_object: @ppga
          }
          validate_task_assigned(@passing_tests_base,'PPGA-QA-FLDS',expected_vals) do |wt|
            quality_required_fields = [
              :ppga_carb_certificate_review,
              :ppga_ca_01350_addendum_review,
              :ppga_scgen_010_review,
              :ppga_ts_130_review,
              :ppga_ts_241_review,
              :ppga_ts_242_review,
              :ppga_ts_282_review,
              :ppga_ts_330_review,
              :ppga_ts_331_review,
              :ppga_ts_342_review,
              :ppga_ts_399_review,
              :ppga_ul_csa_etl_review,
              :ppga_fda_certificate_accession_letter_review,
              :ppga_ca_battery_charger_system_cert_review,
              :ppga_formaldehyde_test_review,
              :ppga_phthalate_test_review,
              :ppga_heavy_metal_test_review,
              :ppga_lead_cadmium_test_review,
              :ppga_lead_paint_review,
              :ppga_msds_review
            ]
            validate_model_field_payload(wt,quality_required_fields)
          end
        end
        it "should assign QA approval" do
          @passing_tests_base += ['PPGA-MERCH-APPROVE','PPGA-QA-FLDS']
          expected_vals = {
            name: "Approve plant #{@plant.name} for product group #{@product_group.name}",
            group_code: 'QUALITY',
            class_name: @wftest,
            view_path: @ppga_view_path,
            target_object: @ppga
          }
          validate_task_assigned(@passing_tests_base,'PPGA-QA-APPROVE',expected_vals) do |wt|
            validate_model_field_payload(wt,[:ppga_qa_approved_date])
          end
        end
        it "should assign PC required fields" do
          @passing_tests_base += ['PPGA-MERCH-APPROVE','PPGA-QA-FLDS','PPGA-QA-APPROVE']
          expected_vals = {
            name: "Enter required Prod Comp fields (#{@plant.name}/#{@product_group.name})",
            group_code: 'PRODUCTCOMP',
            class_name: @wftest,
            view_path: @ppga_view_path,
            target_object: @ppga
          }
          validate_task_assigned(@passing_tests_base,'PPGA-PC-FLDS',expected_vals) do |wt|
            pc_required_fields = [
              :ppga_sample_coc_review,
              :ppga_triage_document_review
            ]
            validate_model_field_payload(wt,pc_required_fields)
          end
        end
        it "should assign PC approval" do
          @passing_tests_base += ['PPGA-MERCH-APPROVE','PPGA-QA-FLDS','PPGA-QA-APPROVE','PPGA-PC-FLDS']
          expected_vals = {
            name: "Approve plant #{@plant.name} for product group #{@product_group.name}",
            group_code: 'PRODUCTCOMP',
            class_name: @wftest,
            view_path: @ppga_view_path,
            target_object: @ppga
          }
          validate_task_assigned(@passing_tests_base,'PPGA-PC-APPROVE',expected_vals) do |wt|
            validate_model_field_payload(wt,[:ppga_pc_approved_date])
          end
        end
        it "should assign PC Exec approval after PC Approval" do
          @passing_tests_base += ['PPGA-MERCH-APPROVE','PPGA-QA-FLDS','PPGA-QA-APPROVE','PPGA-PC-FLDS','PPGA-PC-APPROVE']
          expected_vals = {
            name: "Approve plant #{@plant.name} for product group #{@product_group.name}",
            group_code: 'EXPRODUCTCOMP',
            class_name: @wftest,
            view_path: @ppga_view_path,
            target_object: @ppga
          }
          validate_task_assigned(@passing_tests_base,'PPGA-PCE-APPROVE',expected_vals) do |wt|
            validate_model_field_payload(wt,[:ppga_pc_approved_date_executive])
          end
        end
      end
    end
  end
end
