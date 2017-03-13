require 'open_chain/custom_handler/pepsi/pepsi_custom_definition_support'

module ConfigMigrations; module Pepsi; class Sow1126RenameFields
  include OpenChain::CustomHandler::Pepsi::PepsiCustomDefinitionSupport

  def up
    update_state_toggle_buttons
    update_label
  end

  def down
    rollback_state_toggle_buttons
    rollback_label
  end


  def update_state_toggle_buttons
    stb = StateToggleButton.where(date_custom_definition_id: cdefs[:prod_pgcs_validated_date].id).first
    if stb
      stb.update_attributes! activate_text: "Validate (PGCS)", deactivate_text: "Revoke Validation (PGCS)"
    end

    stb = StateToggleButton.where(date_custom_definition_id: cdefs[:prod_audited_date].id).first
    if stb
      stb.update_attributes! activate_text: "Pass Audit (PGCS)", deactivate_text: "Revoke Audit (PGCS)"
    end
  end

  def update_label
    cdef = CustomDefinition.where(id: cdefs[:prod_pgcs_validated_date]).first
    if cdef
      cdef.update_attributes! label: "Validated Date (PGCS)"
    end

    cdef = CustomDefinition.where(id: cdefs[:prod_pgcs_validated_by]).first
    if cdef
      cdef.update_attributes! label: "Validated By (PGCS)"
    end
  end

  def rollback_state_toggle_buttons
    stb = StateToggleButton.where(date_custom_definition_id: cdefs[:prod_pgcs_validated_date].id).first
    if stb
      stb.update_attributes! activate_text: "Validate (PWF)", deactivate_text: "Revoke Validation (PWF)"
    end

    stb = StateToggleButton.where(date_custom_definition_id: cdefs[:prod_audited_date].id).first
    if stb
      stb.update_attributes! activate_text: "Pass Audit (PWF)", deactivate_text: "Revoke Audit (PWF)"
    end
  end

  def rollback_label
    cdef = CustomDefinition.where(id: cdefs[:prod_pgcs_validated_date]).first
    if cdef
      cdef.update_attributes! label: "Validated Date (PWF)"
    end

    cdef = CustomDefinition.where(id: cdefs[:prod_pgcs_validated_by]).first
    if cdef
      cdef.update_attributes! label: "Validated By (PWF)"
    end
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([:prod_pgcs_validated_date, :prod_pgcs_validated_by, :prod_audited_date])

    @cdefs
  end

end; end; end;