if MasterSetup.production_env?
  require 'open_chain/new_relic_setup_middleware'
  OpenChain::NewRelicSetupMiddleware.set_constant_custom_attributes
  # Insert this first, this ensures that every single request will get tagged w/ the custom attributes
  # that we want to record so that every failure that occurs prior to our application code can have these
  # atributes
  Rails.application.middleware.insert 0, OpenChain::NewRelicSetupMiddleware
end