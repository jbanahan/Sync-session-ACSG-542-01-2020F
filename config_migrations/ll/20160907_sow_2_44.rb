require 'open_chain/custom_handler/lumber_liquidators/lumber_order_default_value_setter'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_helper'
module ConfigMigrations; module LL; class Sow244
  
  def up
    ActiveRecord::Base.transaction do
      create_fields
      create_groups
    end
  end

  def down
    ActiveRecord::Base.transaction do
      remove_groups
      remove_fields
    end
  end

  def defs
    OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionHelper.prep_custom_definitions [
        :ord_comp_docs_submitted_date, :ord_comp_docs_receipt_confirmed_date, :ord_inspection_requested_date, :ord_production_start_date_planned,
        :ord_production_start_date_actual, :ord_production_delay_first_reported, :ord_production_delay, :ord_po_escalation
      ]
  end

  def create_groups
    Group.where(system_code:'AGENTPRODCOMP').first_or_create! name: 'Agent/Product Compliance'
    Group.where(system_code:'AGENTSOURCING').first_or_create! name: 'Agent Sourcing'
  end

  def remove_groups
    Group.where("system_code IN (?)",['AGENTPRODCOMP', 'AGENTSOURCING']).each {|g| g.destroy}
  end

  def create_fields
    puts "creating new fields"
    ActiveRecord::Base.transaction do
      FieldValidatorRule.where(
      model_field_uid:defs[:ord_comp_docs_submitted_date].model_field_uid,
      module_type:"Order"
      ).first_or_create!.update_attributes(can_edit_groups:"AGENTPRODCOMP",can_view_groups:"AGENTPRODCOMP\nALL")

      FieldValidatorRule.where(
      model_field_uid:defs[:ord_comp_docs_receipt_confirmed_date].model_field_uid,
      module_type:"Order"
      ).first_or_create!.update_attributes(can_edit_groups:"PRODUCTCOMP",can_view_groups:"PRODUCTCOMP\nALL")

      FieldValidatorRule.where(
      model_field_uid:defs[:ord_inspection_requested_date].model_field_uid,
      module_type:"Order"
      ).first_or_create!.update_attributes(can_edit_groups:"QUALITY",can_view_groups:"ALL")

      FieldValidatorRule.where(
      model_field_uid:defs[:ord_production_start_date_planned].model_field_uid,
      module_type:"Order"
      ).first_or_create!.update_attributes(can_edit_groups:"AGENTSOURCING",can_view_groups:"AGENTSOURCING\nALL")

      FieldValidatorRule.where(
      model_field_uid:defs[:ord_production_start_date_actual].model_field_uid,
      module_type:"Order"
      ).first_or_create!.update_attributes(can_edit_groups:"AGENTSOURCING",can_view_groups:"AGENTSOURCING\nALL")

      FieldValidatorRule.where(
      model_field_uid:defs[:ord_production_delay_first_reported].model_field_uid,
      module_type:"Order"
      ).first_or_create!.update_attributes(can_edit_groups:"AGENTSOURCING",can_view_groups:"AGENTSOURCING\nALL")

      FieldValidatorRule.where(
      model_field_uid:defs[:ord_production_delay].model_field_uid,
      module_type:"Order"
      ).first_or_create!.update_attributes(can_edit_groups:"AGENTSOURCING\nSOURCING",can_view_groups:"AGENTSOURCING\nALL")

      FieldValidatorRule.where(
      model_field_uid:defs[:ord_po_escalation].model_field_uid,
      module_type:"Order"
      ).first_or_create!.update_attributes(can_edit_groups:"AGENTSOURCING\nSOURCING",can_view_groups:"AGENTSOURCING\nALL")

      CustomDefinition.last.update_attributes(updated_at:Time.now) # force ModelField reload
    end
  end

  def remove_fields
    custom_defs_to_delete = defs.values.collect {|cd| cd.model_field_uid}
    FieldValidatorRule.where("model_field_uid IN (?)", custom_defs_to_delete).destroy_all
    defs.values.each {|cd| cd.destroy}
    CustomDefinition.last.update_attributes(updated_at:Time.now) # force ModelField reload
  end
end; end end
