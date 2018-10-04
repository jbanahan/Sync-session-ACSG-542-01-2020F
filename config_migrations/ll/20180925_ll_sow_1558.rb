require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_helper'

module ConfigMigrations; module LL; class Sow1558

  def up
    OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionHelper.prep_custom_definitions([:prod_country_of_origin])
  end

  def down
    # No need to remove custom definition.
  end

end; end; end