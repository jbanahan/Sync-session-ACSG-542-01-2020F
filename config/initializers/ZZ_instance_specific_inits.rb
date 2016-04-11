if !Rails.env.test? && ActiveRecord::Base.connection.table_exists?('master_setups') && MasterSetup.count > 0
  require 'open_chain/custom_handler/lumber_liquidators/lumber_system_init'
  OpenChain::CustomHandler::LumberLiquidators::LumberSystemInit.init

  require 'open_chain/custom_handler/vandegrift/vandegrift_system_init'
  OpenChain::CustomHandler::Vandegrift::VandegriftSystemInit.init  
end
