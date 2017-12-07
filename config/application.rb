require File.expand_path('../boot', __FILE__)

require 'rails/all'

if defined?(Bundler)
  # If you precompile assets before deploying to production,
  #  use this line
  Bundler.require *Rails.groups(:assets => %w(development test))
  # If you want your assets lazily compiled in production,
  #  use this line
  # Bundler.require(:default, :assets, Rails.env)
end

require 'csv'
require 'json'

# This is required solely for the version of paperclip we're currently using, once we can move to 
# a v5 series of that gem (where aws v2 support was added), this can be removed.
# This must be required before any models are loaded, since paperclip attempts to load the AWS namespace
# during the 'extended' method callback of the models (so at load time). 
require 'aws-sdk-v1'

module OpenChain
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # JavaScript files you want as :defaults (application.js is always included).
    # config.action_view.javascript_expansions[:defaults] = %w(jquery rails)

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    if Rails.env.production?
      config.middleware.use(ExceptionNotification::Rack,
        :email => {
          :email_prefix => "[VFI Track Exception]",
          :sender_address => %{"Exception Notifier" <bug@vandegriftinc.com>},
          :exception_recipients => %w{bug@vandegriftinc.com}
        }
      )
    end

    config.active_record.schema_format = :sql
    if Rails.env.test?
      initializer :after => :initialize_dependency_mechanism do
        ActiveSupport::Dependencies.mechanism = :load
      end
    end

    # In rails 4 use custom-configuration setting instead
    # These are meant to ONLY house settings that might be machine specific.  In essence, it should only be used
    # for things that are meant to be run in production, but out of the normal application flow and a secondary backend system
    # ...such as disabling outbound notifications when reprocessing files or disabling other functionality that would normally
    # be on or controlled system-wide by the MasterSetup custom features
    config.vfitrack = {}
    if File.exists?("config/vfitrack_settings.yml")
      settings = YAML::load_file("config/vfitrack_settings.yml")
      if settings.is_a?(Hash)
        config.vfitrack = settings.with_indifferent_access
      end
    end

    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

    config.assets.precompile += %w( vendor_portal.js vendor_portal.css trade_lanes.js trade_lanes.css chain_vendor_maint.css chain_vendor_maint.js chain_admin.css chain_admin.js )

    config.action_mailer.delivery_method = :postmark

    email_settings = YAML::load_file("config/email.yml")
    postmark_api_key = email_settings[::Rails.env][:postmark_api_key] unless email_settings[::Rails.env].nil?
    config.action_mailer.postmark_settings = { :api_key => postmark_api_key }

    ::AWS_CREDENTIALS = YAML::load_file 'config/s3.yml'

    config.paperclip_defaults = {
      :storage => :s3,
      :s3_credentials => ::AWS_CREDENTIALS,
      :s3_permissions => :private,
      :bucket => 'chain-io',
      # Anything matching this regular expression is turned into an underscore
      :restricted_characters => /[\x00-\x1F\/\\:\*\?\"<>\|]/u
    }

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
    config.middleware.insert_before ActionDispatch::ParamsParser, OpenChain::RackRequestInflater

    if Rails.env.production?
      require 'open_chain/new_relic_setup_middleware'
      OpenChain::NewRelicSetupMiddleware.set_constant_custom_attributes
      # Insert this first, this ensures that every single request will get tagged w/ the custom attributes
      # that we want to record so that every failure that occurs prior to our application code can have these
      # atributes
      config.middleware.insert 0, OpenChain::NewRelicSetupMiddleware
    end

    config.hostname = `hostname`.strip
  end
end
