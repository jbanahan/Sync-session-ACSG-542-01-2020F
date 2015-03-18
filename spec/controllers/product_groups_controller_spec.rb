require 'spec_helper'

describe ProductGroupsController do
  describe :index do
    it "should restrict to admins" do
      sign_in_as Factory(:user)
      get :index
      expect(response).to be_redirect
      expect(flash[:errors]).to_not be_empty
    end
    it "should render" do
      sign_in_as Factory(:admin_user)
      get :index
      expect(response).to be_success
      expect(flash[:errors]).to be_blank
    end
  end
end
