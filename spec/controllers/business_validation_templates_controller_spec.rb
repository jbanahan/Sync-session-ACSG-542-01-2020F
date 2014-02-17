require 'spec_helper'

describe BusinessValidationTemplatesController do
  before :each do
    activate_authlogic
  end
  describe :index do
    before :each do
      @bv_templates = [Factory(:business_validation_template)]
    end
    it "should require admin" do
      u = Factory(:user)
      UserSession.create! u
      get :index
      expect(response).to be_redirect
      expect(assigns(:bv_templates)).to be_nil
    end
    it "should load templates" do
      u = Factory(:admin_user)
      UserSession.create! u
      get :index
      expect(response).to be_success
      expect(assigns(:bv_templates)).to eq @bv_templates
    end
  end
  describe :show do 
    before :each do 
      @t = Factory(:business_validation_template)
    end
    it "should require admin" do
      u = Factory(:user)
      UserSession.create! u
      get :show, id: @t.id
      expect(response).to be_redirect
      expect(assigns(:bv_template)).to be_nil
    end
    it "should load templates" do
      u = Factory(:admin_user)
      UserSession.create! u
      get :show, id: @t.id
      expect(response).to be_success
      expect(assigns(:bv_template)).to eq @t
    end
  end
end
