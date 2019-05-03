require 'open_chain/custom_handler/polo/polo_custom_definition_support'
module ConfigMigrations; module Polo; class RlSow1675
  include OpenChain::CustomHandler::Polo::PoloCustomDefinitionSupport

  def up
    cdefs
    add_field_validations
    nil
  end

  def down
    delete_field_validations
    nil
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([:ax_export_status_manual])
  end

  def add_field_validations
    fvr = FieldValidatorRule.where(model_field_uid:cdefs[:ax_export_status_manual].model_field_uid).first_or_create!
    fvr.one_of = "EXPORTED"
    fvr.save!
  end

  def delete_field_validations
    fvr = FieldValidatorRule.where(model_field_uid:cdefs[:ax_export_status_manual].model_field_uid).first
    fvr.destroy if fvr.present?
  end
end; end; end