require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

class InitializeLumberCustomFieldsFor2022 < ActiveRecord::Migration
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport

  def up
    if MasterSetup.get.custom_feature?("Lumber Liquidators")
      self.class.prep_custom_definitions([:shp_master_bol_unknown])
    end
  end

end
