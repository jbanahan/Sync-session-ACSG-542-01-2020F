require 'spec_helper'

describe BusinessValidationRulesController do
  before :each do

  end

  describe :create do
    before :each do
      @bvr = Factory(:business_validation_rule)
      @bvt = @bvr.business_validation_template
    end

    it 'should require admin' do
      u = Factory(:user)
      sign_in_as u
      post :create, 
            business_validation_template_id: @bvt.id, 
            business_validation_rule: {
              "rule_attributes_json" => '{"valid":"json-1"}'
            }
      expect(response).to be_redirect
    end

    it "should create the correct rule" do
      u = Factory(:admin_user)
      sign_in_as u
      post :create, 
            business_validation_template_id: @bvt.id, 
            business_validation_rule: {
              "rule_attributes_json" => '{"valid":"json-2"}',
              "type" => "ValidationRuleManual"
            }
      expect(response).to be_redirect
      new_rule = BusinessValidationRule.last
      new_rule.business_validation_template.id.should == @bvt.id
      new_rule.rule_attributes_json.should == '{"valid":"json-2"}'
    end

    it "should only save for valid JSON" do
      u = Factory(:admin_user)
      sign_in_as u
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
      @bvt = @bvr.business_validation_template
    end

    it 'should require admin' do
      u = Factory(:user)
      sign_in_as u
      get :edit, id: @bvr.id, business_validation_template_id: @bvt.id
      expect(response).to be_redirect
    end

    it "should load the correct rule to edit" do
      u = Factory(:admin_user)
      sign_in_as u
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
      @bvt = @bvr.business_validation_template
    end

    it "should update criterions when search_criterions_only is set" do
      u = Factory(:admin_user)
      sign_in_as u
      post :update,
          id: @bvr.id,
          business_validation_template_id: @bvt.id,
          search_criterions_only: true,
          business_validation_rule: {search_criterions: [{"mfid" => "ent_cust_name", 
              "datatype" => "string", "label" => "Customer Name", 
              "operator" => "eq", "value" => "Monica Lewinsky"}]}
      @bvr.search_criterions.length.should == 1
      @bvr.search_criterions.first.value.should == "Monica Lewinsky"
    end

    it 'should require admin' do
      u = Factory(:user)
      sign_in_as u
      post :update, id: @bvr.id, business_validation_template_id: @bvt.id
      expect(response).to be_redirect
    end

    it "should update the correct rule" do
      u = Factory(:admin_user)
      sign_in_as u
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

  describe :edit_angular do
    before :each do
      @sc = Factory(:search_criterion)
      # Use an actual concrete rule class rather than the base 'abstract' class to validate we're getting the correct data back
      # since there's some handling required in these cases
      @bvt = Factory(:business_validation_template)
      @rule = ValidationRuleAttachmentTypes.new description: "DESC", fail_state: "FAIL", name: "NAME", rule_attributes_json: '{"test":"testing"}'
      @rule.search_criterions << @sc
      @rule.business_validation_template = @bvt
      @rule.save!
    end

    it "should render the correct model_field and business_rule json" do
      u = Factory(:admin_user)
      sign_in_as u
      get :edit_angular, id: @rule.id
      r = JSON.parse(response.body)
      expect(r["model_fields"].length).to eq ModelField.find_by_core_module(CoreModule::ENTRY).size
      rule = r["business_validation_rule"]
      expect(rule).to eq({"business_validation_template_id"=>@bvt.id, 
          "description"=>"DESC", "fail_state"=>"FAIL", "id"=>@rule.id, 
          "name"=>"NAME", "rule_attributes_json"=>'{"test":"testing"}', 
          "search_criterions"=>[{"mfid"=>"prod_uid", "operator"=>"eq", "value"=>"x", "label" => "Unique Identifier", "datatype" => "string", "include_empty" => false}]})
    end

    it 'should require admin' do
      u = Factory(:user)
      sign_in_as u
      get :edit_angular, id: @rule.id
      expect(response).to be_redirect
    end
  end

  describe :destroy do
    before :each do
      @bvr = Factory(:business_validation_rule)
      @bvt = @bvr.business_validation_template
    end

    it 'should require admin' do
      u = Factory(:user)
      sign_in_as u
      post :destroy, id: @bvr.id, business_validation_template_id: @bvt.id
      expect { BusinessValidationRule.find(@bvr.id) }.to_not raise_error
      expect(response).to be_redirect
    end

    it "should delete the correct rule" do
      u = Factory(:admin_user)
      sign_in_as u
      post :destroy, id: @bvr.id, business_validation_template_id: @bvt.id
      expect { BusinessValidationRule.find(@bvr.id) }.to raise_error
    end

  end

end
