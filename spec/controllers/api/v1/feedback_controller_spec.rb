require 'spec_helper'

describe Api::V1::FeedbackController do

  before :each do
    @user = Factory(:user)
    allow_api_access @user
  end

  describe :send do
    it "should delay trello card creation" do
      td = double('trello')
      td.should_receive(:create_feedback_card!).with(@user.id,'https://sample.com/abc','Hello world')
      OpenChain::Trello.should_receive(:delay).and_return(td)

      post :send_feedback, url: 'https://sample.com/abc', message:'Hello world'

      expect(response).to be_success
    end
  end
end