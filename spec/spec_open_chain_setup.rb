# This file contains ALL the non-default set for rspec-rails.  It is required / loaded AFTER
# rails_helper and spec_helper.
require File.dirname(__FILE__) + "/factories"
require 'clearance/rspec'
require 'webmock/rspec'
require 'open_chain/delayed_job_extensions'
require 'database_cleaner'

Dir[Rails.root.join("lib/**/*.rb")].sort.each {|f| require f}
# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].sort.each {|f| require f}
include Helpers

RSpec.configure do |config|
  config.raise_errors_for_deprecations!
  #allows us to create anonymous controllers in tests for other base controller classes
  config.infer_base_class_for_anonymous_controllers = true

  config.before(:all) do
    DatabaseCleaner.strategy = :deletion
    WebMock.disable!
    # Several hundred test cases expect there to be a MasterSetup record present, rather than stub'ing
    # it.  We're creating this record for those, but they SHOULDN'T be relying on it.  We'll have to leave
    # this in until such point in time where we can amend those test cases.
    MasterSetup.init_test_setup
    # load "#{Rails.root}/config/routes.rb"
    ModelField.reload
  end
  
  config.after(:all) do
    DatabaseCleaner.clean
  end
  
  config.before(:each, :type => :controller) do
    request.env["HTTP_REFERER"] = "/"
  end

  config.before :each do |example|
    Rails.application.config.vfitrack = {}

    CustomDefinition.skip_reload_trigger = true
    Time.zone = ActiveSupport::TimeZone["UTC"]
    LinkableAttachmentImportRule.clear_cache
    # What the following does is totally prevent any specs from accidentally saving to S3 via
    # the paperclip gem.  This shaves off a fair bit of runtime on the specs as well as not having
    # to rely on the AWS services in the test cases.
    # If you need to use paperclip's S3 saving, append "paperclip: true" to the spec declaration
    # .ie -> it "requires paperclip", paperclip: true do
    unless example.metadata[:paperclip]
      stub_paperclip
    end
    unless example.metadata[:s3]
      stub_s3
    end
    unless example.metadata[:email_log]
      stub_email_logging
    end

    unless example.metadata[:snapshot]
      stub_snapshots
    end

    unless example.metadata[:event_publisher]
      stub_event_publisher
    end

    #clear all registries
    OpenChain::EntityCompare::ComparatorRegistry.clear
    OpenChain::Registries::OrderBookingRegistry.clear
    OpenChain::Registries::PasswordValidationRegistry.clear
    OpenChain::Registries::OrderAcceptanceRegistry.clear
    OpenChain::Registries::CustomizedApiResponseRegistry.clear
    OpenChain::Registries::ShipmentRegistry.clear
    OpenChain::AntiVirus::TestingAntiVirus.scan_value = true
  end

  # Clears out the deliveries array before every test..which is only done automatically
  # for mailer tests.
  config.after(:each) do |example|
    ActionMailer::Base.deliveries = []
    unless example.metadata[:s3]
      unstub_s3
    end

    unstub_snapshots

    # Counteract the application controller (or anything else) setting MasterSetup.current, which bleeds across multiple tests
    # since it's not unset by the controller.
    MasterSetup.current = nil
  end

  # Add a way to cleanly disable delay'ing jobs via rspec metadata.
  # Add :disable_delay_jobs to the rspec describe block.
  config.around(:each, :disable_delayed_jobs) do |example|
    value = Delayed::Worker.delay_jobs

    Delayed::Worker.delay_jobs = false

    example.run

    Delayed::Worker.delay_jobs = value
  end

  config.around(:each, :without_partial_double_verification) do |example|
    config.mock_with :rspec do |mocks|
      original_value = mocks.verify_partial_doubles?
      mocks.verify_partial_doubles = false
      example.run
      mocks.verify_partial_doubles = original_value
    end
  end
end
