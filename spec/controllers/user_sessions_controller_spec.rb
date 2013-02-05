require 'spec_helper'

describe UserSessionsController do
  before :each do
    activate_authlogic
  end
  describe 'index' do
    it "should redirect to new if user not logged in" do
      get :index
      response.should redirect_to new_user_session_path
    end
    it "should redirect to root if user logged in" do
      UserSession.create! Factory(:user)
      get :index
      response.should redirect_to root_path
    end
  end
  describe 'new' do
    it "should redirect if user already logged in" do
      UserSession.create! Factory(:user)
      get :new
      response.should redirect_to root_path
    end
    it "should be success if user not logged in" do
      get :new
      response.should be_success
    end
  end
end
