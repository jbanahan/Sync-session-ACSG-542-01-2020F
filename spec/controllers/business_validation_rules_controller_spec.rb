require 'spec_helper'

describe BusinessValidationRulesController do
  before :each do
    activate_authlogic
  end

  describe :create do
    before :each do
      @bvr = Factory(:business_validation_rule)
      @bvt = Factory(:business_validation_template)
      @bvr.business_validation_template = @bvt; @bvr.save!
    end

    it 'should require admin' do
      u = Factory(:user)
      UserSession.create! u
      post :create, 
            business_validation_template_id: @bvt.id, 
            business_validation_rule: {
              "rule_attributes_json" => '{"valid":"json-1"}'
            }
      expect(response).to be_redirect
    end

    it "should create the correct rule" do
      u = Factory(:admin_user)
      UserSession.create! u
      post :create, 
            business_validation_template_id: @bvt.id, 
            business_validation_rule: {
              "rule_attributes_json" => '{"valid":"json-2"}'
            }
      expect(response).to be_redirect
      new_rule = BusinessValidationRule.last
      new_rule.business_validation_template.id.should == @bvt.id
      new_rule.rule_attributes_json.should == '{"valid":"json-2"}'
    end

    it "should only save for valid JSON" do
      u = Factory(:admin_user)
      UserSession.create! u
      post :create, 
            business_validation_template_id: @bvt.id, 
            business_validation_rule: {
              "rule_attributes_json" => 'This is not valid JSON'
            }
      expect(response).to be_redirect
      flash[:errors].first.should match(/Could not save due to invalid JSON/)
    end
  end

  describe :edit do
    before :each do
      @bvr = Factory(:business_validation_rule)
      @bvt = Factory(:business_validation_template)
      @bvr.business_validation_template = @bvt; @bvr.save!
    end

    it 'should require admin' do
      u = Factory(:user)
      UserSession.create! u
      get :edit, id: @bvr.id, business_validation_template_id: @bvt.id
      expect(response).to be_redirect
    end

    it "should load the correct rule to edit" do
      u = Factory(:admin_user)
      UserSession.create! u
      get :edit, 
            id: @bvr.id,
            business_validation_template_id: @bvt.id, 
            business_validation_rule: {
              "rule_attributes_json" => '{"valid":"json-3"}'
            }
      expect(response).to be_success
      response.request.filtered_parameters["id"].to_i.should == @bvr.id
    end

  end

  describe :update do
    before :each do
      @bvr = Factory(:business_validation_rule)
      @bvt = Factory(:business_validation_template)
      @bvr.business_validation_template = @bvt; @bvr.save!
    end

    it 'should require admin' do
      u = Factory(:user)
      UserSession.create! u
      post :update, id: @bvr.id, business_validation_template_id: @bvt.id
      expect(response).to be_redirect
    end

    it "should update the correct rule" do
      u = Factory(:admin_user)
      UserSession.create! u
      post :update, 
            id: @bvr.id,
            business_validation_template_id: @bvt.id, 
            business_validation_rule: {
              "rule_attributes_json" => '{"valid":"json-4"}'
            }
      expect(response).to be_redirect
      updated_rule = BusinessValidationRule.find(@bvr.id)
      updated_rule.rule_attributes_json.should == '{"valid":"json-4"}'
      updated_rule.business_validation_template.id.should == @bvt.id
    end

  end

  describe :destroy do
    before :each do
      @bvr = Factory(:business_validation_rule)
      @bvt = Factory(:business_validation_template)
      @bvr.business_validation_template = @bvt; @bvr.save!
    end

    it 'should require admin' do
      u = Factory(:user)
      UserSession.create! u
      post :destroy, id: @bvr.id, business_validation_template_id: @bvt.id
      expect { BusinessValidationRule.find(@bvr.id) }.to_not raise_error
      expect(response).to be_redirect
    end

    it "should delete the correct rule" do
      u = Factory(:admin_user)
      UserSession.create! u
      post :destroy, id: @bvr.id, business_validation_template_id: @bvt.id
      expect { BusinessValidationRule.find(@bvr.id) }.to raise_error
    end

  end

end