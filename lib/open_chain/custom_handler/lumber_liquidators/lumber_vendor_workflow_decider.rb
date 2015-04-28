require 'open_chain/workflow_decider'
require 'open_chain/workflow_tester/attachment_type_workflow_test'
require 'open_chain/workflow_tester/multi_state_workflow_test'
require 'open_chain/workflow_tester/model_field_workflow_test'
require 'open_chain/workflow_tester/survey_complete_workflow_test'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
require 'open_chain/custom_handler/lumber_liquidators/lumber_group_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberVendorWorkflowDecider
  extend OpenChain::WorkflowDecider
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  include OpenChain::CustomHandler::LumberLiquidators::LumberGroupSupport

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
    # if vendor is locked, clear incomplete tasks and return
    if vendor.locked?
      workflow_inst.workflow_tasks.where(passed_at:nil).destroy_all
      return nil
    end

    tasks_to_keep = []

    groups = prep_groups ['MERCH','LEGAL','SAPV','PRODUCTCOMP','EXPRODUCTCOMP','TRADECOMP','QUALITY']
    company_cdefs = prep_custom_definitions(custom_definition_keys_by_module_type('Company'))
    vendor_agreement_attachment_type = vendor.attachments.where('attachment_type REGEXP "Vendor Agreement"').pluck(:attachment_type).first

    tasks_to_keep += CompanyTests.create_company_tests vendor, workflow_inst, company_cdefs, groups, vendor_agreement_attachment_type

    plant_cdefs = nil
    plant_cdefs = prep_custom_definitions(custom_definition_keys_by_module_type('Plant'))
    ppga_cdefs = nil
    vendor.plants.each do |plant|
      tasks_to_keep += PlantTests.create_plant_tests(vendor,workflow_inst,plant,plant_cdefs,groups)

      ppga_cdefs ||= prep_custom_definitions(custom_definition_keys_by_module_type('PlantProductGroupAssignment'))
      plant.plant_product_group_assignments.each do |ppga|
        tasks_to_keep += ProductGroupTests.create_product_group_assignment_tests(workflow_inst,ppga,ppga_cdefs,groups)
      end
    end

    workflow_inst.destroy_stale_tasks(tasks_to_keep, tasks_to_keep.compact.collect{ |t| t.task_type_code}.uniq.compact)

    return nil
  end

  def self.custom_definition_keys_by_module_type module_type
    r = []
    CUSTOM_DEFINITION_INSTRUCTIONS.each do |k,v|
      r << k if v[:module_type]==module_type
    end
    r
  end
  private_class_method :custom_definition_keys_by_module_type

  class CompanyTests
    extend OpenChain::WorkflowDecider
    def self.create_company_tests vendor, workflow_inst, company_cdefs, groups, vendor_agreement_attachment_type
      tasks_to_keep = []
      
      merch_fields = make_merch_fields_test(vendor,workflow_inst,company_cdefs,groups)
      tasks_to_keep << merch_fields

      merch_require_vendor_agreement = make_vendor_agreement_test(vendor,workflow_inst,groups)
      tasks_to_keep << merch_require_vendor_agreement

      merch_ok = false
      if merch_fields.test! && merch_require_vendor_agreement.test!
        merch_company_approval = make_merch_company_approval_test(vendor,workflow_inst,company_cdefs,groups)
        tasks_to_keep << merch_company_approval
        merch_ok = merch_company_approval.test!
      end

      legal_ok = false
      if merch_ok
        legal_approval = make_legal_approval_test_if_needed(vendor,workflow_inst,company_cdefs,groups,vendor_agreement_attachment_type)
        tasks_to_keep << legal_approval
        legal_ok = (legal_approval.nil? || legal_approval.test!)
      end
      if merch_ok && legal_ok
        sap_company = make_sap_company_test(vendor,workflow_inst,company_cdefs,groups)
        tasks_to_keep << sap_company
        sap_company.test!
      end
      if merch_ok && legal_ok
        if !vendor_agreement_attachment_type.blank?
          pc_vendor_agreement = make_pc_vendor_agreement_test(vendor,workflow_inst,company_cdefs,groups)
          tasks_to_keep << pc_vendor_agreement
          if pc_vendor_agreement.test!
            pc_approve = make_pc_approval_test(vendor,workflow_inst,company_cdefs,groups)
            tasks_to_keep << pc_approve
            pc_approve.test!
          end
        end
      end
      tasks_to_keep
    end

    def self.make_pc_approval_test vendor, workflow_inst, company_cdefs, groups
      payload = {'model_fields'=>[{'uid'=>company_cdefs[:cmp_pc_approved_date].model_field_uid}]}
      return first_or_create_test! workflow_inst,
        'CMP-PC-APPROVE',
        OpenChain::WorkflowTester::ModelFieldWorkflowTest,
        'Approve vendor (Product Compliance)',
        groups['PRODUCTCOMP'],
        payload,
        nil,
        view_path(vendor)
    end
    def self.make_pc_vendor_agreement_test vendor, workflow_inst, company_cdefs, groups
      payload = {'model_fields'=>[{'uid'=>company_cdefs[:cmp_vendor_agreement_review].model_field_uid}]}
      return first_or_create_test! workflow_inst,
        'CMP-PC-VAGREE',
        OpenChain::WorkflowTester::ModelFieldWorkflowTest,
        'Approve vendor agreement for Product Compliance',
        groups['PRODUCTCOMP'],
        payload,
        nil,
        view_path(vendor)
    end
    def self.make_sap_company_test vendor, workflow_inst, company_cdefs, groups
      payload = {'model_fields'=>[{'uid'=>company_cdefs[:cmp_sap_company].model_field_uid}]}
      return first_or_create_test! workflow_inst,
        'CMP-SAP-COMPANY',
        OpenChain::WorkflowTester::ModelFieldWorkflowTest,
        'Enter SAP Company Number',
        groups['SAPV'],
        payload,
        nil,
        view_path(vendor)
    end
    private_class_method :make_sap_company_test

    #make the legal approval test if required else return nil
    def self.make_legal_approval_test_if_needed vendor, workflow_inst, company_cdefs, groups, attachment_type
      #only build if there is a deviation attached
      return nil if attachment_type && !attachment_type.match(/Deviation/)

      payload = {'model_fields'=>[{'uid'=>company_cdefs[:cmp_legal_approved_date].model_field_uid}]}
      return first_or_create_test! workflow_inst,
        'CMP-LEGAL-APPROVE',
        OpenChain::WorkflowTester::ModelFieldWorkflowTest,
        'Approve vendor with deviation (Legal)',
        groups['LEGAL'],
        payload,
        nil,
        view_path(vendor)
    end
    private_class_method :make_legal_approval_test_if_needed

    def self.make_vendor_agreement_test vendor, workflow_inst, groups
      return first_or_create_test! workflow_inst,
        'CMP-MERCH-VAGREE',
        OpenChain::WorkflowTester::ModelFieldWorkflowTest,
        'Attach Vendor Agreement',
        groups['MERCH'],
        {'model_fields'=>[{'uid'=>'cmp_attachment_types','regex'=>'Vendor Agreement'}]},
        nil,
        view_path(vendor)
    end
    private_class_method :make_vendor_agreement_test

    def self.make_merch_fields_test vendor, workflow_inst, company_cdefs, groups
      field_keys = [
        :cmp_requested_payment_method,
        :cmp_dba_name,
        :cmp_a_r_contact_name,
        :cmp_a_r_contact_email,
        :cmp_requested_payment_method,
        :cmp_approved_payment_method,
        :cmp_payment_terms,
        :cmp_purchasing_contact_name,
        :cmp_purchasing_contact_email,
        :cmp_us_vendor,
        :cmp_vendor_type,
        :cmp_industry,
        :cmp_payment_address,
        :cmp_business_address,
        :cmp_primary_phone
      ]
      fields_payload = {'model_fields'=>[]}
      field_keys.each {|k| fields_payload['model_fields'] << {'uid'=>company_cdefs[k].model_field_uid}}

      return first_or_create_test! workflow_inst,
        'CMP-MERCH-FLDS',
        OpenChain::WorkflowTester::ModelFieldWorkflowTest,
        'Enter required merchandising fields',
        groups['MERCH'],
        fields_payload,
        nil,
        view_path(vendor)
    end
    private_class_method :make_merch_fields_test

    def self.make_merch_company_approval_test vendor, workflow_inst, company_cdefs, groups
      payload = {'model_fields'=>[{'uid'=>company_cdefs[:cmp_merch_approved_date].model_field_uid}]}
      return first_or_create_test! workflow_inst,
        'CMP-MERCH-APPROVE',
        OpenChain::WorkflowTester::ModelFieldWorkflowTest,
        'Approve vendor (Merchandising)',
        groups['MERCH'],
        payload,
        nil,
        view_path(vendor)
    end
    private_class_method :make_merch_company_approval_test



    # def self.due_in_days increment
    #   Time.use_zone('Eastern Time (US & Canada)') {return increment.days.from_now.beginning_of_day}
    # end
    #
    def self.view_path base_object
      "/vendors/#{base_object.id}"
    end
    private_class_method :view_path
  end

  class PlantTests
    extend OpenChain::WorkflowDecider

    def self.create_plant_tests vendor, workflow_inst, plant, plant_cdefs, groups
      tests_to_keep = []

      merch_required_fields = make_merch_fields_test(vendor,workflow_inst,plant,plant_cdefs,groups)
      tests_to_keep << merch_required_fields

      # MERCHANDISING TESTS
      merch_ok = false
      if merch_required_fields.test!
        merch_approve = make_merch_plant_approval_test(vendor, workflow_inst, plant, plant_cdefs, groups)
        tests_to_keep << merch_approve
        merch_ok = merch_approve.test!
      end

      # TRADE COMPLIANCE CHECKS
      if merch_ok && !ModelField.find_by_uid(:plant_product_group_names).process_export(plant,nil,true).blank?
        tc_fields = make_tc_fields_test(vendor, workflow_inst, plant, plant_cdefs, groups)
        tests_to_keep << tc_fields
        if tc_fields.test!
          tc_approve = make_tc_plant_approval_test(vendor, workflow_inst, plant, plant_cdefs, groups)
          tests_to_keep << tc_approve
          tc_approve.test!
        end
      end

      # PRODUCT COMPLIANCE CHECKS
      prod_comp_ok = false
      if merch_ok
        triage_review = make_pc_triage_review_test(vendor, workflow_inst, plant, plant_cdefs, groups)
        tests_to_keep << triage_review
        if triage_review.test!
          pc_approve = make_pc_plant_approval_test(vendor, workflow_inst, plant, plant_cdefs, groups)
          tests_to_keep << pc_approve
          prod_comp_ok = pc_approve.test!
        end
      end

      # PRODUCT COMPLIANCE EXECUTIVE REVIEW CHECKS
      if prod_comp_ok
        exec_triage_review = make_pc_exec_triage_review(vendor, workflow_inst, plant, plant_cdefs, groups)
        tests_to_keep << exec_triage_review
        if exec_triage_review.test!
          exec_approve = make_pc_exec_approve(vendor, workflow_inst, plant, plant_cdefs, groups)
          tests_to_keep << exec_approve
          exec_approve.test!
        end
      end

      tests_to_keep
    end

    def self.make_tc_plant_approval_test vendor, workflow_inst, plant, plant_cdefs, groups
      fields_payload = {'model_fields'=>[]}
      fields_payload['model_fields'] << {'uid'=>plant_cdefs[:plnt_tc_approved_date].model_field_uid}

      return first_or_create_test! workflow_inst,
        'PLNT-TC-APPROVE',
        OpenChain::WorkflowTester::ModelFieldWorkflowTest,
        "Approve Plant (Trade Comp) (Plant: #{plant.name})", 
        groups['TRADECOMP'],
        fields_payload,
        nil,
        view_path(vendor,plant),
        plant
    end
    private_class_method :make_tc_plant_approval_test

    def self.make_tc_fields_test vendor, workflow_inst, plant, plant_cdefs, groups
      fields_payload = {'model_fields'=>[]}
      fields_payload['model_fields'] << {'uid'=>plant_cdefs[:plnt_mid_code].model_field_uid}

      return first_or_create_test! workflow_inst,
        'PLNT-TC-FLDS',
        OpenChain::WorkflowTester::ModelFieldWorkflowTest,
        "Add MID (Plant: #{plant.name})", 
        groups['TRADECOMP'],
        fields_payload,
        nil,
        view_path(vendor,plant),
        plant
    end
    private_class_method :make_tc_fields_test

    def self.make_pc_exec_approve vendor, workflow_inst, plant, plant_cdefs, groups
      fields_payload = {'model_fields'=>[]}
      fields_payload['model_fields'] << {'uid'=>plant_cdefs[:plnt_pc_approved_date_executive].model_field_uid}

      return first_or_create_test! workflow_inst,
        'PLNT-PCE-APPROVE',
        OpenChain::WorkflowTester::ModelFieldWorkflowTest,
        "Approve Plant (Prod Compliance Exec) (Plant: #{plant.name})", 
        groups['EXPRODUCTCOMP'],
        fields_payload,
        nil,
        view_path(vendor,plant),
        plant
    end
    private_class_method :make_pc_exec_approve

    def self.make_pc_exec_triage_review vendor, workflow_inst, plant, plant_cdefs, groups
      fields_payload = {'model_fields'=>[]}
      fields_payload['model_fields'] << {'uid'=>plant_cdefs[:plnt_triage_exec_review].model_field_uid}

      return first_or_create_test! workflow_inst,
        'PLNT-PCE-TRIAGE',
        OpenChain::WorkflowTester::ModelFieldWorkflowTest,
        "Update Triage Document Exec Review (Plant: #{plant.name})", 
        groups['EXPRODUCTCOMP'],
        fields_payload,
        nil,
        view_path(vendor,plant),
        plant
    end
    private_class_method :make_pc_exec_triage_review

    def self.make_pc_plant_approval_test vendor, workflow_inst, plant, plant_cdefs, groups
      fields_payload = {'model_fields'=>[]}
      fields_payload['model_fields'] << {'uid'=>plant_cdefs[:plnt_pc_approved_date].model_field_uid}

      return first_or_create_test! workflow_inst,
        'PLNT-PC-APPROVE',
        OpenChain::WorkflowTester::ModelFieldWorkflowTest,
        "Approve Plant (Product Compliance) (Plant: #{plant.name})", 
        groups['PRODUCTCOMP'],
        fields_payload,
        nil,
        view_path(vendor,plant),
        plant
    end
    private_class_method :make_pc_plant_approval_test

    def self.make_pc_triage_review_test vendor, workflow_inst, plant, plant_cdefs, groups
      fields_payload = {'model_fields'=>[]}
      fields_payload['model_fields'] << {'uid'=>plant_cdefs[:plnt_triage_document_review].model_field_uid}

      return first_or_create_test! workflow_inst,
        'PLNT-TRIAGE-REVIEW',
        OpenChain::WorkflowTester::ModelFieldWorkflowTest,
        "Update Triage Document Review (Plant: #{plant.name})", 
        groups['PRODUCTCOMP'],
        fields_payload,
        nil,
        view_path(vendor,plant),
        plant
    end
    private_class_method :make_pc_triage_review_test

    def self.make_merch_fields_test vendor, workflow_inst, plant, plant_cdefs, groups
      field_keys = [
        :plnt_sap_coo_abbreviation,
        :plnt_country_iso_code,
        :plnt_address,
        :plnt_region,
        :plnt_sap_coo_abbreviation,
        :plnt_dc_ship_to,
        :plnt_company_name_shipper,
        :plnt_company_name_manufacturer,
        :plnt_factory_contact_name,
        :plnt_factory_contact_phone,
        :plnt_factory_contact_email,
        :plnt_logistics_contact_name,
        :plnt_logistics_contact_phone,
        :plnt_logistics_contact_email,
        :plnt_mill_code,
        :plnt_default_origin_port
      ]
      fields_payload = {'model_fields'=>[]}
      field_keys.each {|k| fields_payload['model_fields'] << {'uid'=>plant_cdefs[k].model_field_uid}}

      return first_or_create_test! workflow_inst,
        'PLNT-MERCH-FLDS',
        OpenChain::WorkflowTester::ModelFieldWorkflowTest,
        "Enter required merchandising fields (Plant: #{plant.name})", 
        groups['MERCH'],
        fields_payload,
        nil,
        view_path(vendor,plant),
        plant
    end
    private_class_method :make_merch_fields_test

    def self.make_merch_plant_approval_test vendor, workflow_inst, plant, plant_cdefs, groups
      payload = {'model_fields'=>[{'uid'=>plant_cdefs[:plnt_merch_approved_date].model_field_uid}]}
      return first_or_create_test! workflow_inst,
        'PLNT-MERCH-APPROVE',
        OpenChain::WorkflowTester::ModelFieldWorkflowTest,
        "Approve plant (Merchandising) (Plant: #{plant.name})",
        groups['MERCH'],
        payload,
        nil,
        view_path(vendor,plant),
        plant
    end
    private_class_method :make_merch_plant_approval_test

    def self.view_path vendor, plant
      "/vendors/#{vendor.id}/vendor_plants/#{plant.id}"
    end
  end

  class ProductGroupTests
    extend OpenChain::WorkflowDecider

    def self.create_product_group_assignment_tests workflow_inst, ppga, ppga_cdefs, groups
      tests_to_keep = []

      merch_approve = make_merch_ppga_approval_test(workflow_inst, ppga, ppga_cdefs, groups)
      tests_to_keep << merch_approve
      merch_ok = merch_approve.test!
      
      qa_ok = false
      if merch_ok
        qa_fields = make_qa_ppga_fields(workflow_inst, ppga, ppga_cdefs, groups)
        if qa_fields.test!
          qa_approve = make_qa_ppga_approve(workflow_inst, ppga, ppga_cdefs, groups)
          tests_to_keep << qa_approve
          qa_ok = qa_approve.test!
        end
      end

      pc_ok = false
      if qa_ok
        pc_fields = make_pc_ppga_fields(workflow_inst, ppga, ppga_cdefs, groups)
        tests_to_keep << pc_fields
        if pc_fields.test!
          pc_approve = make_pc_ppga_approve(workflow_inst, ppga, ppga_cdefs, groups)
          tests_to_keep << pc_approve
          pc_ok = pc_approve.test!
        end
      end

      if pc_ok
        pc_exec_approve = make_pce_ppga_approve(workflow_inst, ppga, ppga_cdefs, groups)
        tests_to_keep << pc_exec_approve
        pc_exec_approve.test!
      end

      tests_to_keep
    end

    def self.make_pce_ppga_approve workflow_inst, ppga, ppga_cdefs, groups
      payload = {'model_fields'=>[{'uid'=>ppga_cdefs[:ppga_pc_approved_date_executive].model_field_uid}]}
      return first_or_create_test! workflow_inst,
        'PPGA-PCE-APPROVE',
        OpenChain::WorkflowTester::ModelFieldWorkflowTest,
        "Approve plant #{ppga.plant_name} for product group #{ppga.product_group_name}",
        groups['EXPRODUCTCOMP'],
        payload,
        nil,
        view_path(ppga),
        ppga
    end
    private_class_method :make_pce_ppga_approve

    def self.make_pc_ppga_approve workflow_inst, ppga, ppga_cdefs, groups
      payload = {'model_fields'=>[{'uid'=>ppga_cdefs[:ppga_pc_approved_date].model_field_uid}]}
      return first_or_create_test! workflow_inst,
        'PPGA-PC-APPROVE',
        OpenChain::WorkflowTester::ModelFieldWorkflowTest,
        "Approve plant #{ppga.plant_name} for product group #{ppga.product_group_name}",
        groups['PRODUCTCOMP'],
        payload,
        nil,
        view_path(ppga),
        ppga
    end
    private_class_method :make_pc_ppga_approve

    def self.make_pc_ppga_fields workflow_inst, ppga, ppga_cdefs, groups
      field_keys = [
        :ppga_sample_coc_review,
        :ppga_triage_document_review
      ]
      fields_payload = {'model_fields'=>[]}
      field_keys.each {|k| fields_payload['model_fields'] << {'uid'=>ppga_cdefs[k].model_field_uid}}

      return first_or_create_test! workflow_inst,
        'PPGA-PC-FLDS',
        OpenChain::WorkflowTester::ModelFieldWorkflowTest,
        "Enter required Prod Comp fields (#{ppga.plant_name}/#{ppga.product_group.name})", 
        groups['PRODUCTCOMP'],
        fields_payload,
        nil,
        view_path(ppga),
        ppga
    end
    private_class_method :make_pc_ppga_fields

    def self.make_qa_ppga_approve workflow_inst, ppga, ppga_cdefs, groups
      payload = {'model_fields'=>[{'uid'=>ppga_cdefs[:ppga_qa_approved_date].model_field_uid}]}
      return first_or_create_test! workflow_inst,
        'PPGA-QA-APPROVE',
        OpenChain::WorkflowTester::ModelFieldWorkflowTest,
        "Approve plant #{ppga.plant_name} for product group #{ppga.product_group_name}",
        groups['QUALITY'],
        payload,
        nil,
        view_path(ppga),
        ppga
    end
    private_class_method :make_qa_ppga_approve

    def self.make_merch_ppga_approval_test workflow_inst, ppga, ppga_cdefs, groups
      payload = {'model_fields'=>[{'uid'=>ppga_cdefs[:ppga_merch_approved_date].model_field_uid}]}
      return first_or_create_test! workflow_inst,
        'PPGA-MERCH-APPROVE',
        OpenChain::WorkflowTester::ModelFieldWorkflowTest,
        "Approve plant #{ppga.plant_name} for product group #{ppga.product_group_name}",
        groups['MERCH'],
        payload,
        nil,
        view_path(ppga),
        ppga
    end
    private_class_method :make_merch_ppga_approval_test

    def self.make_qa_ppga_fields workflow_inst, ppga, ppga_cdefs, groups
      field_keys = [
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
      fields_payload = {'model_fields'=>[]}
      field_keys.each {|k| fields_payload['model_fields'] << {'uid'=>ppga_cdefs[k].model_field_uid}}

      return first_or_create_test! workflow_inst,
        'PPGA-QA-FLDS',
        OpenChain::WorkflowTester::ModelFieldWorkflowTest,
        "Enter required QA fields (#{ppga.plant_name}/#{ppga.product_group.name})", 
        groups['QUALITY'],
        fields_payload,
        nil,
        view_path(ppga),
        ppga
    end
    private_class_method :make_qa_ppga_fields

    def self.view_path ppga
      "/vendors/#{ppga.plant.company_id}/vendor_plants/#{ppga.plant_id}/plant_product_group_assignments/#{ppga.id}"
    end
  end
end; end; end; end;
