
require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'
module ConfigMigrations; module AnnInc; class SowAnn20Fields
  include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport
  DEFS = [:ordln_ac_date, :ac_date, :ord_ac_date, :dsp_effective_date,:vend_comments,:ord_type, :dsp_type, :ordln_import_country, :mp_type, :ord_docs_required, :ord_docs_completed_by, :ord_docs_completed_date,:ord_audit_complete_by,:ord_audit_complete_date, :ord_audit_initiated_by, :ord_audit_initiated_date,:ord_cancelled,:ord_split_order]

  def defs
    @defs ||= self.class.prep_custom_definitions DEFS
  end

  def up
    generate_custom_views
    generate_fields
    generate_business_rules
    generate_groups
    generate_buttons
    generate_search_configs defs
  end

  def down
    drop_custom_views
    drop_custom_fields
    drop_business_rules
    drop_groups
    drop_buttons
    drop_searches
  end

  def fix_searches
    drop_searches
    generate_search_configs defs
  end

  def generate_custom_views
    cv = CustomViewTemplate.where(template_identifier: 'order_view').first_or_initialize
    cv.template_path = 'custom_views/ann_inc/orders/show'
    cv.module_type = "Order"
    cv.save!
    cv = CustomViewTemplate.where(template_identifier: 'vendor_orders').first_or_initialize
    cv.template_path = '/custom_view/ann_inc/order_view.html'
    cv.module_type = "Order"
  end

  def drop_custom_views
    CustomViewTemplate.where(template_identifier: 'order_view').destroy_all
    CustomViewTemplate.where(template_identifier: 'vendor_orders').destroy_all
  end

  def drop_custom_fields
    defs = self.class.prep_custom_definitions DEFS
    defs.values.each do |cd|
      cd.custom_values.delete_all
      cd.destroy
    end
    CustomDefinition.last.update_attributes(updated_at:Time.now)
  end

  def drop_business_rules
    bvt = BusinessValidationTemplate.where(name:'Order Review',module_type:'Order').first
    bvt.business_validation_rules.destroy_all if bvt.present?
    bvt.destroy if bvt.present?
    bvt = BusinessValidationTemplate.where(name:'Order Validations',module_type:'Order').first
    bvt.business_validation_rules.destroy_all if bvt.present?
    bvt.destroy if bvt.present?
    bvt = BusinessValidationTemplate.where(name:"Vendor MP Type All Docs",module_type:"Order").first
    bvt.business_validation_rules.destroy_all if bvt.present?
    bvt.destroy if bvt.present?
    bvt = BusinessValidationTemplate.where(name:"Vendor MP Type Upon Request",module_type:"Order").first
    bvt.business_validation_rules.destroy_all if bvt.present?
    bvt.destroy if bvt.present?
    fvr = FieldValidatorRule.where(model_field_uid: 'ord_selling_agent_name', module_type: 'Order').first
    fvr.destroy if fvr.present?
  end

  def drop_groups
    Group.where("system_code IN (?)", ['ANN_USERS','ANN_VENDORS']).each {|q| q.destroy}
  end

  def drop_buttons
    buttons = ["Docs Complete","Audit Complete", "Audit Initiated"]
    StateToggleButton.where(activate_text: buttons).delete_all
  end

  def generate_search_configs cdefs
    make_config "Issued", [
        {field:'ord_closed_at',operator:'null'}
    ], cdefs

    make_config "Docs Not Complete", [
        {field:cdefs[:ord_docs_completed_by].model_field_uid.to_s, operator: 'null'},
        {field:cdefs[:ord_docs_required].model_field_uid.to_s, operator: 'notnull'}
    ], cdefs
    make_config "Docs Completed", [
        {field:cdefs[:ord_docs_completed_by].model_field_uid.to_s, operator: 'notnull'},
        {field:cdefs[:ord_docs_required].model_field_uid.to_s, operator: 'notnull'}
    ], cdefs
    make_config "Docs Attached but not Complete", [
        {field:cdefs[:ord_docs_completed_by].model_field_uid.to_s, operator: 'null'},
        {field:cdefs[:ord_docs_required].model_field_uid.to_s, operator: 'notnull'},
        {field: 'ord_attachment_count', operator: 'gt', val: '0'}
    ], cdefs

    make_config "AC Date - Next 30 Days", [
      {field:cdefs[:ord_ac_date].model_field_uid.to_s,operator:'bdf',val:'30'},
      {field:cdefs[:ord_ac_date].model_field_uid.to_s,operator:'adf',val:'0'}
    ], cdefs

    make_config "AC Date - Next 90 Days", [
        {field:cdefs[:ord_ac_date].model_field_uid.to_s,operator:'bdf',val:'90'},
        {field:cdefs[:ord_ac_date].model_field_uid.to_s,operator:'adf',val:'0'}
    ], cdefs
  end

  def generate_buttons
    defs = self.class.prep_custom_definitions DEFS
    StateToggleButton.where(activate_text: 'Docs Complete').first_or_create!(module_type:'Order',
                                                                             user_custom_definition_id:defs[:ord_docs_completed_by].id,
                                                                             date_custom_definition_id:defs[:ord_docs_completed_date].id,
                                                                             permission_group_system_codes: "ANN_USERS\nANN_VENDORS",
                                                                             activate_text: 'Docs Complete',
                                                                             deactivate_text: 'Docs Incomplete',
                                                                             deactivate_confirmation_text: 'Are you sure you want to invalidate the documents on this order?'
    )

    StateToggleButton.where(activate_text: 'Audit Initiated').first_or_create(module_type: 'Order',
                                                                              user_custom_definition_id: defs[:ord_audit_initiated_by].id,
                                                                              date_custom_definition_id: defs[:ord_audit_initiated_date].id,
                                                                              permission_group_system_codes: 'ANN_USERS',
                                                                              activate_text: 'Audit Initiated',
                                                                              deactivate_text: 'Audit Cancelled',
                                                                              deactivate_confirmation_text: 'Are you sure you want to cancel this audit?')

    StateToggleButton.where(activate_text: 'Audit Complete').first_or_create!(module_type:'Order',
                                                                              user_custom_definition_id:defs[:ord_audit_complete_by].id,
                                                                              date_custom_definition_id:defs[:ord_audit_complete_date].id,
                                                                              permission_group_system_codes:'ANN_USERS',
                                                                              activate_text:'Audit Complete',
                                                                              deactivate_text:'Audit Incomplete',
                                                                              deactivate_confirmation_text:'Are you sure you want to invalidate the document audit?'
    )
  end

  def generate_groups
    Group.where(system_code: 'ANN_USERS').first_or_create!(system_code:'ANN_USERS',name: 'Ann Inc Users',description: 'Ann Inc Employees.')
    Group.where(system_code: 'ANN_VENDORS').first_or_create!(system_code:'ANN_VENDORS',name: 'Ann Inc Vendors',description: 'Ann Inc Vendors')
  end

  def generate_business_rules
    defs = self.class.prep_custom_definitions DEFS
    bvt = BusinessValidationTemplate.where(name: "Order Review", module_type: "Order").first_or_create!(description: 'All orders that have an AC Date before 120 days in docs required with no docs attached')
    bvt.search_criterions.create!(operator:"ada",value:"120",model_field_uid:"ord_window_start") if bvt.search_criterions.empty?
    bvt.search_criterions.create!(operator:"eq",value: 'y', model_field_uid:"#{defs[:ord_docs_required].model_field_uid}") if bvt.search_criterions.count < 2
    bvt.business_validation_rules.create!(
        type:'ValidationRuleFieldFormat',
        name:'Documents Required before 120 days',
        description:'Facility or Supplier has not attached documents and it is within 120 days of AC Date.',
        fail_state:'Review',
        rule_attributes_json: "{\"model_field_uid\":\"#{defs[:ord_docs_completed_date].model_field_uid}\",\"regex\":\".\"}"
    )

    bvt = BusinessValidationTemplate.where(name: "Order Validations", module_type: "Order").first_or_create!(description: 'All orders that have an AC Date past 120 days must have documents attached')
    bvt.search_criterions.create!(operator:"bda",value:"120",model_field_uid:"ord_window_start") if bvt.search_criterions.empty?
    bvt.search_criterions.create!(operator:"eq",value: 'y', model_field_uid:"#{defs[:ord_docs_required].model_field_uid}") if bvt.search_criterions.count < 2
    bvt.business_validation_rules.create!(
        type:'ValidationRuleFieldFormat',
        name:'Documents Required',
        description:'Facility or Supplier has not attached documents and it is beyond 120 days after AC Date.',
        fail_state:'Fail',
        rule_attributes_json: "{\"model_field_uid\":\"ord_attachment_count\",\"regex\":\"[1-9][0-9]?\"}"
    )
    bvr = bvt.business_validation_rules.create!(
        type:'ValidationRuleFieldFormat',
        name:'Documents Not Completed',
        description:'Facility or Supplier has not attached any documents or has not marked Documents Completed and it is beyond 120 days after AC Date.',
        fail_state:'Fail',
        rule_attributes_json: "{\"model_field_uid\":\"#{defs[:ord_docs_completed_date].model_field_uid}\",\"regex\":\"[0-9]\"}"
    )
    bvr.search_criterions.create!(
        operator:'lt',
        value:'1',
        model_field_uid:'ord_attachment_count'
    )
    bvt = BusinessValidationTemplate.where(name: "Vendor MP Type All Docs", module_type: "Order").first_or_create!(description: 'Vendor is MP Type All Docs, but order has docs required set to false')
    bvt.search_criterions.create!(operator:"null", model_field_uid: "#{defs[:ord_docs_required].model_field_uid}")
    bvr = bvt.business_validation_rules.create!(
      type:'OpenChain::CustomHandler::AnnInc::AnnMpTypeAllDocsValidationRule',
      name:'Docs required set to false',
      description:'Docs required set to false',
      fail_state:'Fail'
    )
    bvt.disabled = true
    bvt.save!
    bvt = BusinessValidationTemplate.where(name: "Vendor MP Type Upon Request", module_type: "Order").first_or_create!(description: 'Vendor is MP Type Upon Request, but order has docs required set to false.')
    bvt.search_criterions.create!(operator:"null", model_field_uid: "#{defs[:ord_docs_required].model_field_uid}")
    bvr = bvt.business_validation_rules.create!(
      type: 'OpenChain::CustomHandler::AnnInc::AnnMpTypeUponRequestValidationRule',
      name: 'MP Type Upon Request',
      description: 'Vendor MP Type is Upon Request, but Docs Required is false',
      fail_state: 'Review'
    )
    bvt.disabled = true
    bvt.save!
  end

  def generate_fields
    defs = self.class.prep_custom_definitions DEFS

    # mp_type
    cd = defs[:mp_type]
    fvr = FieldValidatorRule.where(model_field_uid: cd.model_field_uid, module_type: cd.module_type).first_or_initialize
    fvr.can_edit_groups = "ANN_USERS\n"
    fvr.one_of = "Not Participating\nAll Docs\nUpon Request\n"
    fvr.save!

    # dsp_type
    cd = defs[:dsp_type]
    fvr = FieldValidatorRule.where(model_field_uid: cd.model_field_uid, module_type:cd.module_type).first_or_initialize
    fvr.can_edit_groups = "ANN_USERS\n"
    fvr.one_of = "MP\nStandard\nAP\n"
    fvr.save!

    # ord_type
    cd = defs[:ord_type]
    fvr = FieldValidatorRule.where(model_field_uid: cd.model_field_uid, module_type:cd.module_type).first_or_initialize
    fvr.one_of = "MP\nAP\nStandard\n"
    fvr.save!

    fvr = FieldValidatorRule.where(model_field_uid: 'ord_ven_name', module_type: 'Order').first_or_initialize
    fvr.read_only = true
    fvr.save!

    fvr = FieldValidatorRule.where(model_field_uid: 'ord_agent_name', module_type: 'Order').first_or_initialize
    fvr.read_only = true
    fvr.save!

    fvr = FieldValidatorRule.where(model_field_uid: 'ord_selling_agent_name', module_type: 'Order').first_or_initialize
    fvr.read_only = true
    fvr.save!
  end

  def drop_searches
    SearchTableConfig.destroy_all
  end

  def make_config name, hidden_criteria, cdefs
    base_columns = [
        'ord_ord_num',
        'ord_ord_date',
        'ord_window_start',
        'ord_ven_name'
    ]
    base_sorts = [
        {field:'ord_ord_num'}
    ]
    stc = SearchTableConfig.new(name:name,page_uid:'chain-vp-order-panel')
    stc.config_hash = {
        columns: base_columns,
        sorts: base_sorts,
        hiddenCriteria: hidden_criteria
    }
    stc.save!
  end
end; end; end

