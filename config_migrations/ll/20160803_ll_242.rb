require 'open_chain/custom_handler/lumber_liquidators/lumber_order_default_value_setter'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_helper'
module ConfigMigrations; module LL; class Ll242
  def up
    create_fields
    update_defaults
  end

  def down
    ActiveRecord::Base.transaction do
      defs = OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionHelper.prep_custom_definitions [
          :ord_delay_reason, :ord_delay_dispo
                                                                                                               ]
      defs.each_value {|cd| cd.destroy}
      CustomDefinition.last.update_attributes(updated_at:Time.now) # force ModelField reloadp
    end
  end

  def create_fields
    puts "creating new fields"
    ActiveRecord::Base.transaction do
      defs = OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionHelper.prep_custom_definitions [
          :ord_delay_reason, :ord_delay_dispo
                                                                                                               ]

      FieldValidatorRule.where(
          model_field_uid:defs[:ord_delay_reason].model_field_uid,
          module_type:'Order'
      ).first_or_create!

      FieldValidatorRule.where(
          model_field_uid:defs[:ord_delay_dispo].model_field_uid,
          module_type:'Company'
      ).first_or_create!.update_attributes(can_edit_groups:'', can_view_groups:'') # groups TBD
    end

    def update_defaults
      cdefs = OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionHelper.prep_custom_definitions([:ord_delay_reason, :ord_delay_dispo])

      ll_ord_delay_reason = FieldValidatorRule.where(model_field_uid:cdefs[:ord_delay_reason].model_field_uid).first
      ll_ord_delay_reason.one_of = ["Incorrect Lead Time", "Production Capacity", "Raw Materials", "Holiday Shutdown",
      "Other (requires comment)", "Raw Materials – Defective", "Raw Materials – Shortage/Delay", "Machine/Equipment Repair or Failure",
      "Quality – Internal Quality Issue", "Quality – Pending Product Test Results", "Quality – Product Testing Failure",
      "Quality – Pending Final Inspection Results", "Quality – Final Inspection Failure", "Lacey Supplemental Documentation",
      "Holiday Shutdown", "Carrier Allocation", "Production Capacity", "Consolidation Adjustment", "Late Booking by Vendor",
      "Late Shipment", "Incorrect Lead Time", "Other (requires comment)"].join("\n")
      ll_ord_delay_reason.save!

      ll_ord_delay_dispo = FieldValidatorRule.where(model_field_uid:cdefs[:ord_delay_dispo].model_field_uid).first
      ll_ord_delay_dispo.one_of = ["LL", "Vendor", "Other"].join("\n")
      ll_ord_delay_dispo.save!
    end
  end
end; end; end
