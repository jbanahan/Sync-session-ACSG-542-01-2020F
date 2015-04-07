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

    groups = prep_groups ['MERCH']
    company_cdefs = prep_custom_definitions(custom_definition_keys_by_module_type('Company'))
    merch_fields = make_merch_fields_test(vendor,workflow_inst,company_cdefs,groups)
    merch_fields.test!

    merch_require_vendor_agreement = make_vendor_agreement_test(vendor,workflow_inst,groups)
    merch_require_vendor_agreement.test!
    return nil
  end


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
    required_merch_field_keys = [
      :cmp_requested_payment_method
    ]
    merch_fields_payload = {'model_fields'=>[]}
    required_merch_field_keys.each {|k| merch_fields_payload['model_fields'] << {'uid'=>company_cdefs[k].model_field_uid}}

    return first_or_create_test! workflow_inst,
      'CMP-MERCH-FLDS',
      OpenChain::WorkflowTester::ModelFieldWorkflowTest,
      'Enter required merchandising fields',
      groups['MERCH'],
      merch_fields_payload,
      nil,
      view_path(vendor)
  end
  private_class_method :make_merch_fields_test


  def self.custom_definition_keys_by_module_type module_type
    r = []
    CUSTOM_DEFINITION_INSTRUCTIONS.each do |k,v|
      r << k if v[:module_type]==module_type
    end
    r
  end
  private_class_method :custom_definition_keys_by_module_type

  # def self.due_in_days increment
  #   Time.use_zone('Eastern Time (US & Canada)') {return increment.days.from_now.beginning_of_day}
  # end
  #
  def self.view_path base_object
    "/vendors/#{base_object.id}"
  end
  private_class_method :view_path

end; end; end; end;
