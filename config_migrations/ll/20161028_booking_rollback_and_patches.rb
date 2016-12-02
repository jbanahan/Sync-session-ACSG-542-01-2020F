require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
module ConfigMigrations; module LL; class BookingRollbackAndPatches
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  CDEF_FIELDS = [:ord_production_start_date_planned]
  def prep_custom_definitions
    self.class.prep_custom_definitions CDEF_FIELDS
  end

  def up
    cdefs = prep_custom_definitions
    update_production_start_date_planned_permissions cdefs
  end

  def down
    cdefs = prep_custom_definitions
  end

  def update_production_start_date_planned_permissions cdefs
    cd = cdefs[:ord_production_start_date_planned]
    fvr = FieldValidatorRule.where(model_field_uid:cd.model_field_uid.to_s,module_type:'Order').first_or_create!
    fvr.update_attributes(can_view_groups:"ALL\nORDERACCEPT",can_edit_groups:"ALL\nORDERACCEPT")
  end
end; end; end
