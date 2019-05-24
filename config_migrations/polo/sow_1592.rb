require 'open_chain/custom_handler/polo/polo_custom_definition_support'

module ConfigMigrations; module Polo; class RlSow1592
  include OpenChain::CustomHandler::Polo::PoloCustomDefinitionSupport

  def up
    cdefs
    ModelField.update_last_loaded true
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([:japanese_leather_definition, :eu_sanitation_certificate, :japan_sanitation_certificate, :korea_sanitation_certificate])
  end

end; end; end