require 'spec_helper'

describe UsersController do
  before :each do
    @user = Factory(:user)
    activate_authlogic
    UserSession.create! @user
  end
  describe 'hide_message' do
    it "should hide message" do
      post :hide_message, :message_name=>'mn'
      @user.reload
      @user.hide_message?('mn').should be_true
      response.should be_success
      JSON.parse(response.body).should == {'OK'=>'OK'}
    end
  end
end
