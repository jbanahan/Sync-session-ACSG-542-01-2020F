require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
module ConfigMigrations; module LL; class VpOrderPanelStc
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  CDEF_FIELDS = [:ord_forecasted_handover_date, :ord_delay_reason, :ord_delay_dispo]
  def prep_custom_definitions
    self.class.prep_custom_definitions CDEF_FIELDS
  end

  def up
    cdefs = prep_custom_definitions
    create_search_table_configs cdefs
    update_field_validator_rules cdefs
  end

  def down
    remove_search_table_configs
  end

  def update_field_validator_rules cdefs
    h = {ord_closed_by:{ro:true},
      ord_currency: {ro:true},
      ord_delay_reason: {can_edit:'SOURCING', can_view:'ALL'},
      ord_delay_dispo: {can_edit:'SOURCING', can_view:'ALL'},
      ord_factory_syscode:{ro:true},
      ord_imp_id:{ro:true},
      ord_imp_syscode:{ro:true},
      ord_imp_name:{ro:true},
      ord_system_code:{ro:true},
      ord_mode:{ro:true},
      ord_ship_from_id:{ro:true},
      ord_tppsr_db_id:{ro:true},
      ord_ven_syscode:{ro:true}
    }
    h.each do |k, v|
      fvr = FieldValidatorRule.where(model_field_uid:k, module_type:'Order').first_or_create!
      fvr.read_only = true if v[:ro]
      fvr.can_edit_groups = v[:can_edit] if v[:can_edit]
      fvr.can_view_groups = v[:can_view] if v[:can_view]
      fvr.save!
    end
    ModelField.reload true
  end

  def remove_search_table_configs
    SearchTableConfig.where(page_uid:'chain-vp-order-panel').destroy_all
  end

  def create_search_table_configs cdefs
    make_config "Not Approved", [
      {field:'ord_approval_status', operator:'null'},
      {field:'ord_closed_at', operator:'null'}
    ], cdefs
    make_config "All Open", [
      {field:'ord_closed_at', operator:'null'}
    ], cdefs
    make_config "Approved", [
      {field:'ord_approval_status', operator:'notnull'},
      {field:'ord_closed_at', operator:'null'}
    ], cdefs
    make_config "Window Closing Next 14 Days", [
      {field:cdefs[:ord_forecasted_handover_date].model_field_uid.to_s, operator:'bdf', val:'14'},
      {field:cdefs[:ord_forecasted_handover_date].model_field_uid.to_s, operator:'adf', val:'0'}
    ], cdefs
    make_config "All", [
      ], cdefs
  end

  def make_config name, hidden_criteria, cdefs
    base_columns = [
      'ord_ord_num',
      'ord_window_end',
      cdefs[:ord_forecasted_handover_date].model_field_uid.to_s,
      'ord_approval_status',
      'ord_rule_state'
    ]
    base_sorts = [
      {field:'ord_ord_num'}
    ]
    stc = SearchTableConfig.new(name:name, page_uid:'chain-vp-order-panel')
    stc.config_hash = {
      columns: base_columns,
      sorts: base_sorts,
      hiddenCriteria: hidden_criteria
    }
    stc.save!
  end
end; end; end
