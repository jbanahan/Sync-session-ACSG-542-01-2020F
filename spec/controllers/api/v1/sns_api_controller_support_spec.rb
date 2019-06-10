require 'spec_helper'

describe Api::V1::SnsApiControllerSupport, controller: false do

  subject {
    Class.new(Api::V1::Admin::AdminApiController) do 
      include Api::V1::SnsApiControllerSupport
    end.new
  }

  describe "set_integration_user" do
    it "sets up User.current and Time.zone to User.integration's values" do
      integration = User.integration
      request = double("request")
      env = {}
      allow(subject).to receive(:request).and_return request
      allow(request).to receive(:env).and_return env
      # This is a bit hokey, but I don't want to put code to check if the exeption notifier data hash exists in the api_controller code, because it
      # always should, and is a programming/setup error if it doesn't...except in this unit test case.
      subject.send(:prep_exception_notifier)

      subject.set_integration_user do |user|
        expect(User.current).to eq integration
        expect(Time.zone).to eq ActiveSupport::TimeZone[integration.time_zone]
      end

      expect(User.current).to be_nil
      expect(Time.zone).to eq ActiveSupport::TimeZone[Rails.application.config.time_zone]
    end
  end
  
end