require 'spec_helper'

describe HmController do
  before :each do
    MasterSetup.get.update_attributes(custom_features:'H&M')
  end
  describe :index do
    it "should not allow view unless master user" do
      u = Factory(:user)
      sign_in_as u
      get :index
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq 1
    end
    it "should not allow view unless H&M custom feature enabled" do
      MasterSetup.get.update_attributes(custom_features:'')
      u = Factory(:master_user)
      sign_in_as u
      get :index
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq 1
    end
    it "should allow for master user with custom feature enabled" do
      u = Factory(:master_user)
      sign_in_as u
      get :index
      expect(response).to be_success
    end
  end

  describe :show_po_lines do
    before :each do
      u = Factory(:master_user)
      sign_in_as u
    end
    it "should render page" do
      get :show_po_lines
      expect(response).to be_success
    end
  end
end
