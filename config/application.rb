require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require 'csv'
require 'json'

# A plain require doesn't work here because the 'lib' dir hasn't been added to the lib load path yet..so
# the easiest thing to do is just directly require the file (since we know the exact path to it and
# the path for this application.rb file is always static - thus the following should always work)
require_relative '../lib/open_chain/load_environment'
OpenChain::LoadEnvironment.load

module OpenChain
  class Application < Rails::Application

    OpenChain::LoadEnvironment.application_load

    # This flag will tell us if we're running from the consle (or rake)
    # If that's the case, there's several things we don't really want to verify were loaded
    # so as to allow for command line utils to be able to run to fix things and such.
    run_from_console = OpenChain::LoadEnvironment.running_from_console?

    # Set the newrelic license key up directly.  There appears to be a manual way to load the license key
    # but it works just as well to just set it as an environment variable.

    # The reason I'm not using dig here is because the key semantics change in Rails 4->5->6 such that a symbol is required for the first value and then strings for
    # the next when pulling from secrets...the following will work for all rails versions.
    # (rails 4 -> Rails.application.secrets.dig(:new_relic, "license_key") vs Rails.application.secrets.dig("new_relic", "license_key"))
    new_relic_key = Rails.application.secrets.try(:[], "new_relic").try(:[], "license_key")
    ENV["NEW_RELIC_LICENSE_KEY"] = new_relic_key if new_relic_key.present?

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Do not swallow errors in after_commit/after_rollback callbacks.
    config.active_record.raise_in_transactional_callbacks = true

    if Rails.env.production?
      config.middleware.use(ExceptionNotification::Rack,
        ignore_if: lambda { |env, exception| exception.is_a?(ActionController::InvalidAuthenticityToken) || exception.is_a?(UnreportedError) || MasterSetup.get.custom_feature?("Suppress Exception Emails") },
        email: {
          email_prefix: "[VFI Track Exception]",
          sender_address: %{"Exception Notifier" <bug@vandegriftinc.com>},
          exception_recipients: %w{bug@vandegriftinc.com}
        }
      )
    end

    # The following config pretty much completely disables strong_parameters.  When we start to use them and eliminate
    # the protected_attributes, this can be removed.  We can do a hybrid of the two by removing the following config
    # and adding `before_action { params.permit! }` for any controllers we know are still protected by attr_accessible.
    config.action_controller.permit_all_parameters = false
    config.active_record.schema_format = :sql
    config.active_job.queue_adapter = :delayed_job
    config.action_mailer.delivery_method = :postmark
    config.active_record.include_root_in_json = true
    ActiveSupport::JSON::Encoding.time_precision = 0

    if Rails.env.test?
      initializer :after => :initialize_dependency_mechanism do
        ActiveSupport::Dependencies.mechanism = :load
      end
    end

    # These are meant to ONLY house settings that might be machine specific.  In essence, it should only be used
    # for things that are meant to be run in production, but out of the normal application flow and a secondary backend system
    # ...such as disabling outbound notifications when reprocessing files or disabling other functionality that would normally
    # be on or controlled system-wide by the MasterSetup custom features
    config.vfitrack = {}
    if File.exist?("config/vfitrack_settings.yml")
      config.vfitrack = Rails.application.config_for(:vfitrack_settings)
    end

    if !Rails.env.test?
      # See newrelic note above about why try is used here rather than dig
      postmark_api_key = Rails.application.secrets.try(:[], "postmark").try(:[], "postmark_api_key")
      raise "Postmark email settings must be configured under the 'postmark' key in config/secrets.yml." if postmark_api_key.blank? && !run_from_console
      config.action_mailer.postmark_settings = { api_token: postmark_api_key }
    end

    aws = Rails.application.secrets["aws"]&.with_indifferent_access
    if aws.blank?
      raise "AWS credentials must be configured under the 'aws' key in config/secrets.yml." unless run_from_console
    else
      config.paperclip_defaults = {
        storage: :s3,
        s3_credentials: aws,
        s3_permissions: :private,
        s3_region: aws['region'],
        bucket: 'chain-io',
        # Anything matching this regular expression is turned into an underscore
        restricted_characters: /[\x00-\x1F\/\\:\*\?\"<>\|]/u
      }
    end

    # Add an interpolation so that you can use :master_setup_uuid in the Paperclip has_attached_file 'path'
    # config variable.
    #
    # This is done this way primarily as a means to defer the instantiation of the master setup
    # object used for the Paperclip attachment path until the point when an attachment is actually
    # saved vs. when a class containing it is loaded.  This has the most impact on testing so that creation
    # of a MasterSetup occurs not at classloading (and thus can ensure the same master setup is used
    # to describe the attachment path as is used potentially in a test case), but also resolves potential
    # problems in migrations that occur when loading a
    # MasterSetup instance during classloading (see original histories of classes w/ has_attached_file in them)
    Paperclip.interpolates(:master_setup_uuid) do |attachment, style|
      MasterSetup.get.uuid
    end

    require 'open_chain/rack_request_inflater'
    config.middleware.insert_before ActionDispatch::Flash, OpenChain::RackRequestInflater

    config.hostname = `hostname`.strip
    config.action_mailer.deliver_later_queue_name = 'default'
  end
end
