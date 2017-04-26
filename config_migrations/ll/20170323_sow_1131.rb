require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_helper'
module ConfigMigrations; module LL; class SOW1131
  def up
    create_mass_updatable_field_validations
  end

  def create_mass_updatable_field_validations
    ModelField.find_by_core_module(CoreModule::ORDER).each do |mf|
      next unless mf.user_accessible?
      fvr = FieldValidatorRule.where(model_field_uid: mf.uid, module_type: mf.model).first
      if fvr.present?
        fvr.update_attribute(:mass_edit, true)
      else
        FieldValidatorRule.create!(model_field_uid: mf.uid, module_type: mf.model, mass_edit: true)
      end
    end
  end
end; end; end