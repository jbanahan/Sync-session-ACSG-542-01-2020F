require 'spec_helper'

describe BusinessValidationTemplatesController do
  before :each do

  end
  describe :index do
    before :each do
      @bv_templates = [Factory(:business_validation_template)]
    end
    it "should require admin" do
      u = Factory(:user)
      sign_in_as u
      get :index
      expect(response).to be_redirect
      expect(assigns(:bv_templates)).to be_nil
    end
    it "should load templates" do
      u = Factory(:admin_user)
      sign_in_as u
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
      sign_in_as u
      get :show, id: @t.id
      expect(response).to be_redirect
      expect(assigns(:bv_template)).to be_nil
    end
    it "should load templates" do
      u = Factory(:admin_user)
      sign_in_as u
      get :show, id: @t.id
      expect(response).to be_success
      expect(assigns(:bv_template)).to eq @t
    end
  end

  describe :new do

    before :each do
      @t = Factory(:business_validation_template)
    end

    it "should require admin" do
      u = Factory(:user)
      sign_in_as u
      get :new, id: @t.id
      expect(response).to be_redirect
      expect(assigns(:bv_template)).to be_nil
    end

    it "should load the correct template" do
      u = Factory(:admin_user)
      sign_in_as u
      get :new, id: @t.id
      expect(response).to be_success
      response.request.filtered_parameters["id"].to_i.should == @t.id
    end

  end

  describe :create do

    before :each do
      @t = Factory(:business_validation_template)
    end

    it "should require admin" do
      u = Factory(:user)
      sign_in_as u
      post :create, id: @t.id
      expect(response).to be_redirect
      expect(assigns(:bv_template)).to be_nil
    end

    it "should create the correct template" do
      u = Factory(:admin_user)
      sign_in_as u
      post :create, id: @t.id
      expect(response).to be_success
      expect { BusinessValidationTemplate.find(@t.id) }.to_not raise_error
    end

  end

  describe :update do

    before :each do
      @t = Factory(:business_validation_template)
    end

    it "should require admin" do
      u = Factory(:user)
      sign_in_as u
      post :update, id: @t.id
      expect(response).to be_redirect
      expect(assigns(:bv_template)).to be_nil
    end

  end

  describe :edit do

    before :each do
      @t = Factory(:business_validation_template)
    end

    it "should require admin" do
      u = Factory(:user)
      sign_in_as u
      get :edit, id: @t.id
      expect(response).to be_redirect
      expect(assigns(:bv_template)).to be_nil
    end

    it "should load the correct template" do
      u = Factory(:admin_user)
      sign_in_as u
      get :edit, id: @t.id
      expect(response).to be_success
      response.request.filtered_parameters["id"].to_i.should == @t.id
    end

  end

  describe :destroy do

    before :each do
      @t = Factory(:business_validation_template)
    end

    it "should require admin" do
      u = Factory(:user)
      sign_in_as u
      post :destroy, id: @t.id
      expect(response).to be_redirect
      expect(assigns(:bv_template)).to be_nil
    end

    it "should destroy the BVT" do
      u = Factory(:admin_user)
      sign_in_as u
      previous_id = @t.id
      post :destroy, id: @t.id
      expect { BusinessValidationTemplate.find(previous_id) }.to raise_error
    end

  end

end
