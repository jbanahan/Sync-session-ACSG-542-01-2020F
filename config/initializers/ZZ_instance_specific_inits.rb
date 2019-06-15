if !Rails.env.test? && MasterSetup.master_setup_initialized?
  require 'open_chain/custom_handler/ann_inc/ann_inc_system_init'
  OpenChain::CustomHandler::AnnInc::AnnIncSystemInit.init

  require 'open_chain/custom_handler/lumber_liquidators/lumber_system_init'
  OpenChain::CustomHandler::LumberLiquidators::LumberSystemInit.init

  require 'open_chain/custom_handler/vandegrift/vandegrift_system_init'
  OpenChain::CustomHandler::Vandegrift::VandegriftSystemInit.init

  require 'open_chain/custom_handler/pepsi/pepsi_system_init'
  OpenChain::CustomHandler::Pepsi::PepsiSystemInit.init

  require 'open_chain/custom_handler/masterbrand/masterbrand_system_init'
  OpenChain::CustomHandler::Masterbrand::MasterbrandSystemInit.init

  require 'open_chain/custom_handler/polo/polo_system_init'
  OpenChain::CustomHandler::Polo::PoloSystemInit.init

  if Rails.env.development?
    require 'open_chain/custom_handler/dev_system_init'
    OpenChain::CustomHandler::DevSystemInit.init
  end

  require 'open_chain/custom_handler/default_instance_specific_init'
  OpenChain::CustomHandler::DefaultInstanceSpecificInit.init
end

