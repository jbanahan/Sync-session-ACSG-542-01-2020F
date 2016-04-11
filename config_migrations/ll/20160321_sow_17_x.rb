require 'open_chain/custom_handler/lumber_liquidators/lumber_order_default_value_setter'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_helper'
module ConfigMigrations; module LL; class Sow171
  def up
    create_fields
    update_defaults
  end
  def down
    ActiveRecord::Base.transaction do
      defs = OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionHelper.prep_custom_definitions [
        :cmp_default_handover_port,:cmp_default_inco_term,:cmp_default_country_of_origin,
        :ord_country_of_origin
      ]
      custom_defs_to_delete = defs.values.collect {|cd| cd.model_field_uid}
      FieldValidatorRule.where("model_field_uid IN (?)",(custom_defs_to_delete + [:ord_payment_terms,:ord_fob_point])).destroy_all
      defs.values.each {|cd| cd.destroy}
      CustomDefinition.last.update_attributes(updated_at:Time.now) # force ModelField reloadp
    end
  end

  def create_fields
    puts "creating new fields"
    ActiveRecord::Base.transaction do
      defs = OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionHelper.prep_custom_definitions [
        :cmp_default_handover_port,:cmp_default_inco_term,:cmp_default_country_of_origin,
        :ord_country_of_origin
      ]

      FieldValidatorRule.where(
      model_field_uid:defs[:cmp_default_handover_port].model_field_uid,
      module_type:'Company'
      ).first_or_create!.update_attributes(can_edit_groups:'',can_view_groups:'') #plug in groups when Rebecca replies

      FieldValidatorRule.where(
      model_field_uid:defs[:cmp_default_inco_term].model_field_uid,
      module_type:'Company'
      ).first_or_create!.update_attributes(can_edit_groups:'',can_view_groups:'') #plug in groups when Rebecca replies

      FieldValidatorRule.where(
      model_field_uid:defs[:cmp_default_country_of_origin].model_field_uid,
      module_type:'Company'
      ).first_or_create!.update_attributes(can_edit_groups:'',can_view_groups:'') #plug in groups when Rebecca replies

      FieldValidatorRule.where(
      model_field_uid:defs[:ord_country_of_origin].model_field_uid,
      module_type:'Order'
      ).first_or_create!.update_attributes(can_edit_groups:'',can_view_groups:'') #plug in groups when Rebecca replies

      FieldValidatorRule.where(
      model_field_uid: :ord_payment_terms,
      module_type:'Order'
      ).first_or_create!.update_attributes(read_only:false,can_edit_groups:'',can_view_groups:'') #plug in groups when Rebecca replies

      FieldValidatorRule.where(
      model_field_uid: :ord_fob_point,
      module_type:'Order'
      ).first_or_create!.update_attributes(read_only:false,can_edit_groups:'',can_view_groups:'') #plug in groups when Rebecca replies

      CustomDefinition.last.update_attributes(updated_at:Time.now) # force ModelField reload
    end
  end
  def update_defaults
    puts "updating order defaults"
    Order.scoped.each do |ord|
      OpenChain::CustomHandler::LumberLiquidators::LumberOrderDefaultValueSetter.set_defaults ord
    end
  end
end; end end
