require 'dalli'
require 'mono_logger'

OpenChain::Application.configure do
  # Settings specified here will take precedence over those in config/environment.rb
  # Each file will be at most 10MB, storing at most 5 of them
  config.logger = MonoLogger.new(Rails.root.join("log", Rails.env + ".log"), 5, 10485760)

  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the webserver when you make code changes.
  config.cache_classes = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
#  config.action_view.debug_rjs             = true

  config.action_controller.perform_caching = false #on for testing cache, turn this OFF
  # Use a different cache store in production
  # We want to to make sure to namespace the data based on the instance name of the app to
  # definitively avoid all potential key collision and cross contamination of cache keys
  memcache_namespace = "Chain-#{Rails.root.basename.to_s}"
  config.cache_store = :dalli_store, 'localhost', {:namespace => memcache_namespace, :compress=>true}

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  config.assets.precompile += ['legacy.js','html5shim.js']

  # Do not compress assets
  config.assets.compress = false

  # Expands the lines which load the assets
  config.assets.debug = true 

  # Raise exception on mass assignment protection for Active Record models
  config.active_record.mass_assignment_sanitizer = :strict

  # Log the query plan for queries taking more than this (works
  # with SQLite, MySQL, and PostgreSQL)
  config.active_record.auto_explain_threshold_in_seconds = 0.5

  # don't serve any precompiled assets
  config.serve_static_assets = true #need this to allow /public directory to work

  config.broadcast_model_events = false
end

