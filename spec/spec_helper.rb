require 'spork'

Spork.prefork do
# This file is copied to spec/ when you run 'rails generate rspec:install'
  ENV["RAILS_ENV"] ||= 'test'
  require File.expand_path("../../config/environment", __FILE__)
  require 'rspec/rails'
  require File.dirname(__FILE__) + "/factories"
  require 'clearance/rspec'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
  Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}
  include Helpers
  
  Rails.logger.level = 4
  RSpec.configure do |config|
    # == Mock Framework
    #
    # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
    #
    # config.mock_with :mocha
    # config.mock_with :flexmock
    # config.mock_with :rr
    config.mock_with :rspec

    # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
    config.fixture_path = "#{::Rails.root}/spec/fixtures"

    # If you're not using ActiveRecord, or you'd prefer not to run each of your
    # examples within a transaction, remove the following line or assign false
    # instead of true.
    config.use_transactional_fixtures = true
    config.before(:all) do
      DeferredGarbageCollection.start unless ENV['CIRCLECI']
    end
    config.before(:each, :type => :controller) do
        request.env["HTTP_REFERER"] = "/"
    end

    config.after(:each, :type => :controller) do
      # Counteract the application controller setting MasterSetup.current, which bleeds across multiple tests
      # since it's not unset by the controller.
      MasterSetup.current = nil
    end

    config.after(:all) do
      DeferredGarbageCollection.reconsider unless ENV['CIRCLECI']
    end
  end
end

Spork.each_run do
  # Requires everything in lib
  warn_level = $VERBOSE
  begin
    $VERBOSE = nil
    load "#{Rails.root}/config/routes.rb"
    Dir[Rails.root.join("lib/**/*.rb")].each {|f| load f}
    ModelField.reload
  ensure
    $VERBOSE = warn_level
  end
end

