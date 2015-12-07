require 'open_chain/custom_handler/custom_view_selector'
require 'open_chain/custom_handler/lumber_liquidators/lumber_view_selector'

if MasterSetup.get.system_code = 'll' 
  OpenChain::CustomHandler::CustomViewSelector.register_handler OpenChain::CustomHandler::LumberLiquidators::LumberViewSelector
end