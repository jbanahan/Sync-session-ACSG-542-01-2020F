# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require File.dirname(__FILE__) + "/factories"
require 'clearance/rspec'
require 'webmock/rspec'
require 'open_chain/delayed_job_extensions'
require 'database_cleaner'

# don't auto-run minitest which we don't use, but is required by ActiveSupport
Test::Unit.run = true if defined?(Test::Unit) && Test::Unit.respond_to?(:run=)

Dir[Rails.root.join("lib/**/*.rb")].sort.each {|f| require f}
# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].sort.each {|f| require f}
include Helpers

Rails.logger.level = 4
RSpec.configure do |config|
  config.raise_errors_for_deprecations!
  #allows us to create anonymous controllers in tests for other base controller classes
  config.infer_base_class_for_anonymous_controllers = true

  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  config.mock_with :rspec

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true
  config.before(:all) do
    DatabaseCleaner.strategy = :deletion
    WebMock.disable!
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
    stub_event_publisher
    Time.zone = ActiveSupport::TimeZone["UTC"]
    LinkableAttachmentImportRule.clear_cache
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
    unless example.metadata[:email_log]
      stub_email_logging
    end

    unless example.metadata[:snapshot]
      stub_snapshots
    end

    #clear all registries
    OpenChain::EntityCompare::ComparatorRegistry.clear
    OpenChain::Registries::OrderBookingRegistry.clear
    OpenChain::Registries::PasswordValidationRegistry.clear
    OpenChain::Registries::OrderAcceptanceRegistry.clear
    OpenChain::Registries::CustomizedApiResponseRegistry.clear
    OpenChain::Registries::ShipmentRegistry.clear
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

  config.mock_with :rspec do |mocks|
    # In RSpec 3, `any_instance` implementation blocks will be yielded the receiving
    # instance as the first block argument to allow the implementation block to use
    # the state of the receiver.
    # In RSpec 2.99, to maintain compatibility with RSpec 3 you need to either set
    # this config option to `false` OR set this to `true` and update your
    # `any_instance` implementation blocks to account for the first block argument
    # being the receiving instance.
    mocks.yield_receiver_to_any_instance_implementation_blocks = true
  end

  # rspec-rails 3 will no longer automatically infer an example group's spec type
  # from the file location. You can explicitly opt-in to the feature using this
  # config option.
  # To explicitly tag specs without using automatic inference, set the `:type`
  # metadata manually:
  #
  #     describe ThingsController, :type => :controller do
  #       # Equivalent to being in spec/controllers
  #     end
  config.infer_spec_type_from_file_location!

  # Add a way to cleanly disable delay'ing jobs via rspec metadata.
  # Add :disable_delay_jobs to the rspec describe block.
  config.around(:each, :disable_delayed_jobs) do |example|
    value = Delayed::Worker.delay_jobs

    Delayed::Worker.delay_jobs = false

    example.run

    Delayed::Worker.delay_jobs = value
  end
end
