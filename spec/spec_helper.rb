require 'spork'
require 'sucker_punch/testing/inline' #don't create new threads for sucker_punch

Spork.prefork do
# This file is copied to spec/ when you run 'rails generate rspec:install'
  ENV["RAILS_ENV"] ||= 'test'
  require File.expand_path("../../config/environment", __FILE__)
  require 'rspec/rails'
  require File.dirname(__FILE__) + "/factories"
  require 'clearance/rspec'
  require 'webmock/rspec'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
  Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}
  include Helpers
  
  Rails.logger.level = 4
  RSpec.configure do |config|
    #allows us to create anonymous controllers in tests for other base controller classes
    config.infer_base_class_for_anonymous_controllers = true
    
    config.fixture_path = "#{::Rails.root}/spec/fixtures"

    config.mock_with :rspec

    # If you're not using ActiveRecord, or you'd prefer not to run each of your
    # examples within a transaction, remove the following line or assign false
    # instead of true.
    config.use_transactional_fixtures = true
    config.before(:all) do
      WebMock.disable!
    end
    config.before(:each, :type => :controller) do
        request.env["HTTP_REFERER"] = "/"
    end
    config.before :each do 
      EntitySnapshotSupport.disable_async = true
      CustomDefinition.skip_reload_trigger = true
      stub_event_publisher
      Time.zone = ActiveSupport::TimeZone["UTC"]
      # What the following does is totally prevent any specs from accidentally saving to S3 via
      # the paperclip gem.  This shaves off a fair bit of runtime on the specs as well as not having
      # to rely on the AWS services in the test cases.
      # If you need to use paperclip's S3 saving, append "paperclip: true" to the spec declaration
      # .ie -> it "requires paperclip", paperclip: true do
      
      # In Rspec 2.99/3.0 "example" below needs to be changed to "ex"
      unless example.metadata[:paperclip] 
        stub_paperclip
      end
      unless example.metadata[:s3] 
        stub_s3
      end
    end
    
    # Clears out the deliveries array before every test..which is only done automatically
    # for mailer tests.
    config.after(:each) do
      ActionMailer::Base.deliveries = []
      unless example.metadata[:s3]
        unstub_s3
      end
    end

    config.after(:each, :type => :controller) do
      # Counteract the application controller setting MasterSetup.current, which bleeds across multiple tests
      # since it's not unset by the controller.
      MasterSetup.current = nil
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

