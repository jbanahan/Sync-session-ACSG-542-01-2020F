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

    config.middleware.use ExceptionNotification::Rack,
      :email => {
        :email_prefix => "[VFI Track Exception]",
        :sender_address => %{"Exception Notifier" <bug@vandegriftinc.com>},
        :exception_recipients => %w{bug@vandegriftinc.com}
      }
      
    config.active_record.schema_format = :sql
    if Rails.env.test? 
      initializer :after => :initialize_dependency_mechanism do 
        ActiveSupport::Dependencies.mechanism = :load 
      end 
    end

    # Enable the asset pipeline
    config.assets.enabled = true

    # Add the favicon subdir to the assets path
    config.assets.paths << "#{Rails.root}/app/assets/images/favicons"

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

    config.action_mailer.delivery_method = :postmark
    
    email_settings = YAML::load(File.open("#{::Rails.root.to_s}/config/email.yml"))
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
  end
end
