require 'dalli'
require 'mono_logger'

OpenChain::Application.configure do
  # Settings specified here will take precedence over those in config/environment.rb

  # The production environment is meant for finished, "live" apps.
  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # If you have no front-end server that supports something like X-Sendfile,
  # just comment this out and Rails will serve the files
  # Specifies the header that your server uses for sending files
  # For nginx:
  config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect'

  # Use MonoLogger, which is a non-locking Logger implementation, needed since
  # mutexes are no longer allowed in signal traps in ruby 2.0.
  # No need for log file rotation, an external process (logrotate) handles that now.
  config.logger = MonoLogger.new(Rails.root.join("log", Rails.env + ".log"))
  # Only want to see errors in the log (default is :info which shows request information)
  # For some reason the standard rails logger level symbol and log_level won't work when you 
  # use a different logging implementation (MonoLogger)
  config.logger.level = Logger::WARN

  # Use a different cache store in production
  # We want to to make sure to namespace the data based on the instance name of the app
  # to definitively avoid all potential collision and cross contamination of cache keys
  memcache_namespace = "Chain-#{Rails.root.basename.to_s}"
  config.cache_store = :dalli_store, 'chain-cache.roatcx.0001.use1.cache.amazonaws.com', {:namespace => memcache_namespace, :compress=>true}

  # Disable Rails's static asset server
  # In production, Apache or nginx will already do this
  config.serve_static_assets = false

  # Enable serving of images, stylesheets, and javascripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false

  # Enable threaded mode
  # config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify
  
  config.assets.precompile += ['legacy.js','html5shim.js']

  # Compress JavaScript and CSS
  config.assets.compress = true

  # Don't fallback to assets pipeline
  config.assets.compile = false

  # Generate digests for assets URLs
  config.assets.digest = true

  #set path to include local ruby so forked processes can call bundle & rake
  ENV['PATH'] = "#{ENV['PATH']}:/usr/local/ruby/bin"

  config.broadcast_model_events = true
end
