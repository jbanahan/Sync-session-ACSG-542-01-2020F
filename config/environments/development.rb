require 'dalli'

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false
  Rails.application.routes.default_url_options.merge!({ protocol: "http", host: "localhost", port: 3000 })

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  # Setting this to true makes pages loads take a LONG time.
  config.assets.debug = false

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true
  config.assets.enabled = false

  # This forces all *_url links generated in mailers to be http (we don't run w/ https in dev)
  config.action_mailer.default_url_options = { protocol: "http" }
  Rails.application.routes.default_url_options.merge!({ protocol: "http", host: "localhost", port: 3000 })

  # Docker's local network is different from the host machine's and is not a set ip range
  # Lets prevent the console from being clogged up with unhelpful warnings about this
  config.web_console.whiny_requests = false

  # Settings specified here will take precedence over those in config/environment.rb
  # Each file will be at most 10MB, storing at most 5 of them
  config.logger = Logger.new(Rails.root.join("log", Rails.env + ".log"), 5, 10485760)

  memcache_server, memcache_settings = CacheWrapper.memcache_settings
  config.cache_store = :dalli_store, memcache_server, memcache_settings

  config.broadcast_model_events = false
end

