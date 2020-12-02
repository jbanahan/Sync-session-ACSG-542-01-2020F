Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.cache_classes = true

  # Do not eager load code on boot. This avoids loading your whole application
  # just for the purpose of running a single test. If you are using a tool that
  # preloads Rails for running tests, you may have to set it to true.
  config.eager_load = false

  # Configure static file server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.headers = { 'Cache-Control' => 'public, max-age=3600' }
  config.assets.check_precompiled_asset = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false
  Rails.application.routes.default_url_options.merge!({ protocol: "http", host: "localhost", port: 3000 })

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test
  config.action_mailer.default_url_options = { protocol: "https", host: "localhost", port: 3000 }

  # Randomize the order test cases are executed.
  config.active_support.test_order = :random

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  config.broadcast_model_events = false

  # For some reason, 'mysqldump' isn't available on our CI docker environment (even though mysql is)...so, just use the ruby schema output
  # It's not like we need it on the system anyway.
  config.active_record.schema_format = :ruby

  # This is solely there to pacify rails.  This is test environment, so I don't care if it's code, this way I don't have to
  # deploy a secrets.yml file for or CI environment.
  config.secret_key_base = "f2fe81d75e1794d5a4b998842a9eece3e29c3033453e754bfd7b3dbd92df0a8b48d3f2c82367cc64e0e7b34a8be6d1aacd508776af4fd7eae99c7abacf545dc5"
  config.active_job.queue_adapter = :test
end
