require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module ConfigMigrations; module LL; class Sow1378
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport

  CDEF_FIELDS = [:cmp_default_handover_port]

  def prep_custom_definitions
    self.class.prep_custom_definitions CDEF_FIELDS
  end

  def up
    cdefs = prep_custom_definitions
    make_field_validations cdefs
    rename_field
  end

  def down
    cdefs = prep_custom_definitions
    remove_field_validations cdefs
    revert_field_rename
  end

  def make_field_validations cdefs
    fvr_default_handover_port = FieldValidatorRule.where(model_field_uid:cdefs[:cmp_default_handover_port].model_field_uid.to_s, module_type:'Company').first_or_create!
    fvr_default_handover_port.update_attributes!(can_view_groups:"ADMIN", can_edit_groups:"ADMIN", comment:"Field is now deprecated, and has been limited to admin users only.")

    fvr_fob_point = FieldValidatorRule.where(model_field_uid: :ord_fob_point, module_type:'Order').first_or_create!
    fvr_fob_point.update_attributes!(read_only:true, can_edit_groups:"")
  end

  def remove_field_validations cdefs
    fvr_default_handover_port = FieldValidatorRule.where(model_field_uid:cdefs[:cmp_default_handover_port].model_field_uid.to_s, module_type:'Company').first
    fvr_default_handover_port.update_attributes!(can_view_groups:"", can_edit_groups:"", comment:"") unless fvr_default_handover_port.nil?

    fvr_fob_point = FieldValidatorRule.where(model_field_uid: :ord_fob_point, module_type:'Order').first
    fvr_fob_point.update_attributes!(read_only:false, can_edit_groups:"LOGISTICS/nSOURCING") unless fvr_fob_point.nil?
  end

  def rename_field
    fl = FieldLabel.where(model_field_uid:'ord_fob_point').first_or_create!
    fl.label = 'Delivery Location'
    fl.save!
  end

  def revert_field_rename
    fl = FieldLabel.where(model_field_uid:'ord_fob_point').first_or_create!
    fl.label = 'FOB POINT'
    fl.save!
  end

end; end; end