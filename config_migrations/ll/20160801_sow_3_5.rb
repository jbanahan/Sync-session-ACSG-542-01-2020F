require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_helper'
require 'open_chain/custom_handler/lumber_liquidators/lumber_order_change_comparator'
module ConfigMigrations; module LL; class SOW35

  DEFS ||= [
    :ord_qa_hold_by,
    :ord_qa_hold_date,
    :ordln_qa_approved_by,
    :ordln_qa_approved_date,
    :ord_assigned_agent,
    :ord_inspection_date_planned,
    :ord_inspection_date_completed,
    :ord_testing_date_planned,
    :ord_testing_date_completed,
    :ord_inspector_assigned
  ]

  def up
    create_groups
    defs = create_new_custom_defs
    create_state_toggle_buttons defs
    create_order_business_rules defs
    update_accepted_dates
    update_forecasted_handover_date
  end
  def down
    remove_order_business_rules
    remove_state_toggle_buttons
    remove_custom_defs
    remove_groups
  end

  def update_forecasted_handover_date
    integration = User.integration
    Order.includes(:custom_values).where(closed_at:nil).each do |o|
      if OpenChain::CustomHandler::LumberLiquidators::LumberOrderChangeComparator.set_forecasted_handover_date o
        o.create_snapshot integration
      end
    end
  end

  def update_accepted_dates
    integration = User.integration
    Order.where(approval_status:'Accepted').each do |o|
      snapshots = o.entity_snapshots.order('entity_snapshots.id DESC')
      accepted_snapshot = find_accepted_snapshot snapshots
      if accepted_snapshot
        o.accepted_by = accepted_snapshot.user
        o.accepted_at = accepted_snapshot.created_at
        o.save!
        o.create_snapshot integration
      end
    end
  end

  def find_accepted_snapshot snapshots
    oldest_with = nil
    snapshots.each do |es|
      h = es.snapshot_json
      approval_status = h['entity']['model_fields']['ord_approval_status']
      oldest_with = es if !approval_status.blank?
      break if oldest_with && !approval_status
    end
    oldest_with
  end

  def create_groups
    Group.create!(system_code:'QA_APPROVE_ORDER', name:'QA Approve Orders', description:'QA team members who can approve orders to ship.')
    Group.create!(system_code:'QA_APPROVE_ORDER_EXEC', name:'QA Exec Approve Orders', description:'QA team members who can hold orders from shipping.')
  end

  def remove_groups
    Group.where("system_code IN (?)", ['QA_APPROVE_ORDER', 'QA_APPROVE_ORDER_EXEC']).each {|g| g.destroy}
  end

  def create_new_custom_defs
    defs = OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionHelper.prep_custom_definitions DEFS
    [:ord_inspection_date_planned,
    :ord_inspection_date_completed,
    :ord_testing_date_planned,
    :ord_testing_date_completed,
    :ord_inspector_assigned
    ].each do |def_id|
      cd = defs[def_id]
      fvr = FieldValidatorRule.new(model_field_uid:cd.model_field_uid, module_type:cd.module_type, can_edit_groups:'QA_APPROVE_ORDER', can_view_groups:"QA_APPROVE_ORDER\nALL")
      if def_id==:ord_inspector_assigned
        fvr.one_of = "Bill Ban\nDaniel Wang\nJacky Zhang\nJames Li\nJason Jia\nJohn Zeng\nNick Hu\nPei Feifei\nSadie Yao\nSean Zhu\nTerrence Zhu\nTom Pi\nVilla Xu\n"
      end
      fvr.save!
    end
    defs
  end

  def remove_custom_defs
    OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionHelper.prep_custom_definitions(DEFS).each_value do |cd|
      cd.destroy
    end
  end

  def create_state_toggle_buttons defs
    StateToggleButton.create!(module_type:'OrderLine',
      user_custom_definition_id:defs[:ordln_qa_approved_by].id,
      date_custom_definition_id:defs[:ordln_qa_approved_date].id,
      permission_group_system_codes:'QA_APPROVE_ORDER',
      activate_text:'QA Approve',
      deactivate_text: 'QA Revoke',
      deactivate_confirmation_text: 'Are you sure you want to revoke QA approval?'
    )
    StateToggleButton.create!(module_type:'Order',
      user_custom_definition_id:defs[:ord_qa_hold_by].id,
      date_custom_definition_id:defs[:ord_qa_hold_date].id,
      permission_group_system_codes:'QA_APPROVE_ORDER_EXEC',
      activate_text:'QA Hold',
      activate_confirmation_text: 'Are you sure you want to put this order on QA hold?',
      deactivate_text: 'QA Release'
    )
  end

  def remove_state_toggle_buttons
    StateToggleButton.where(activate_text:'QA Approve', module_type:'OrderLine').destroy_all
    StateToggleButton.where(activate_text:'QA Hold', module_type:'Order').destroy_all
  end

  def create_order_business_rules defs
    bvt = BusinessValidationTemplate.where(name:'Order Validations', module_type:'Order').first_or_create!(description:'Base Order Validations')
    bvt.search_criterions.create!(operator:'notnull', value:'', model_field_uid:'ord_ord_num') if bvt.search_criterions.empty?
    bvt.business_validation_rules.create!(
      type:'ValidationRuleOrderLineFieldFormat',
      name:'QA Approval',
      description:'Every line must be QA Approved',
      fail_state:'Fail',
      rule_attributes_json: "{\"*cf_#{defs[:ordln_qa_approved_date].id}\":{\"regex\":\"[0-9]\"}}"
    )
    bvt.business_validation_rules.create!(
      type:'ValidationRuleFieldFormat',
      name:'No QA Hold',
      description: 'QA Executive has placed order on hold',
      fail_state: 'Fail',
      rule_attributes_json: "{\"model_field_uid\":\"*cf_#{defs[:ord_qa_hold_date].id}\",\"regex\":\"^$\"}"
    )
  end
  def remove_order_business_rules
    bvt = BusinessValidationTemplate.where(name:'Order Validations', module_type:'Order').first
    bvt.business_validation_rules.where("name IN ('QA Approval','No QA Hold')").destroy_all
  end
end; end; end
