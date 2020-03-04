require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

class InitializeLumberCustomFieldsFor1860 < ActiveRecord::Migration
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport


  def up
    # Only run this migration on Lumber system
    if MasterSetup.get.custom_feature?("Lumber Liquidators")
      self.class.prep_custom_definitions([:prod_add_case, :prod_cvd_case, :class_special_program_indicator])
    end
  end
end
