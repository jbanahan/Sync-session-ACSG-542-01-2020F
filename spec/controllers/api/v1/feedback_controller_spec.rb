require 'spec_helper'

describe Api::V1::FeedbackController do

  let!(:user) { Factory(:user) }

  before :each do
    allow_api_access user
  end

  describe "send" do
    it "should send email", :disable_delayed_jobs do
      post :send_feedback, url: 'https://sample.com/abc', message:'Hello world'

      expect(response).to be_success

      expect(ActionMailer::Base.deliveries.length).to eq 1
      m = ActionMailer::Base.deliveries.first
      expect(m.subject).to eq "[VFI Track] [User Feedback] #{user.company.name} - #{user.full_name}"
    end
  end
end