require 'spec_helper'

describe BusinessValidationRulesController do
  before :each do
    activate_authlogic
  end

  describe :create do
    before :each do
      @bvr = Factory(:business_validation_rule)
    end

    it 'should require admin' do
      u = Factory(:user)
      UserSession.create! u
      post :create, id: @bvr.id
      expect(response).to be_redirect
    end

    it "should create the correct rule" do
      u = Factory(:admin_user)
      UserSession.create! u
      post :create, 
            id: @bvr.id, 
            business_validation_rule: {
              "business_validation_template_id" => @bvr.business_validation_template.id,
              "rule_attributes_json" => '{"valid":"json"}'
            }
      expect(response).to be_redirect
      response.request.filtered_parameters["id"].to_i.should == @bvr.id
      expect { BusinessValidationRule.find(@bvr.id) }.to_not raise_error
    end

    it "should only save for valid JSON" do
      u = Factory(:admin_user)
      UserSession.create! u
      post :create, 
            id: @bvr.id, 
            business_validation_rule: {
              "business_validation_template_id" => @bvr.business_validation_template.id,
              "rule_attributes_json" => 'this is not valid JSON'
            }
      expect(response).to be_redirect
      response.request.filtered_parameters["id"].to_i.should == @bvr.id
      flash[:errors].first.should match(/Could not save due to invalid JSON/)
    end
  end

  describe :edit do
    before :each do
      @bvr = Factory(:business_validation_rule)
    end

    it 'should require admin' do
      u = Factory(:user)
      UserSession.create! u
      get :edit, id: @bvr.id
      expect(response).to be_redirect
    end

    it "should load the correct rule to edit" do
      u = Factory(:admin_user)
      UserSession.create! u
      get :edit, 
            id: @bvr.id, 
            business_validation_rule: {
              "business_validation_template_id" => @bvr.business_validation_template.id,
              "rule_attributes_json" => '{"valid":"json"}'
            }
      expect(response).to be_success
      response.request.filtered_parameters["id"].to_i.should == @bvr.id
    end

  end

  describe :update do
    before :each do
      @bvr = Factory(:business_validation_rule)
    end

    it 'should require admin' do
      u = Factory(:user)
      UserSession.create! u
      post :update, id: @bvr.id
      expect(response).to be_redirect
    end

    it "should update the correct rule" do
      u = Factory(:admin_user)
      UserSession.create! u
      post :create, 
            id: @bvr.id, 
            business_validation_rule: {
              "business_validation_template_id" => @bvr.business_validation_template.id,
              "rule_attributes_json" => '{"valid":"json"}'
            }
      expect(response).to be_redirect
      response.request.filtered_parameters["id"].to_i.should == @bvr.id
      expect { BusinessValidationRule.find(@bvr.id) }.to_not raise_error
    end

  end

  describe :destroy do
    before :each do
      @bvr = Factory(:business_validation_rule)
    end

    it 'should require admin' do
      u = Factory(:user)
      UserSession.create! u
      post :destroy, id: @bvr.id
      expect(response).to be_redirect
    end

    it "should delete the correct rule" do
      u = Factory(:admin_user)
      UserSession.create! u
      post :destroy, id: @bvr.id
      expect { BusinessValidationRule.find(@bvr.id) }.to raise_error
    end

  end

end