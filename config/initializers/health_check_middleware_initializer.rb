require 'open_chain/health_check_middleware'

# ActionDispatch::SSL is the middlware that's used to force all endpoints to SSL.  Since we
# don't have SSL running on the actual web serves our healthcheck needs to be HTTP.  Therefore
# we set it up as a middleware that handles the request PRIOR to the SSL one.
if MasterSetup.rails_config.force_ssl.nil? || MasterSetup.rails_config.force_ssl == false
  Rails.application.middleware.insert 0, OpenChain::HealthCheckMiddleware
else
  Rails.application.middleware.insert_before ActionDispatch::SSL, OpenChain::HealthCheckMiddleware
end

