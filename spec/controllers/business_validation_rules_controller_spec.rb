require 'spec_helper'

describe BusinessValidationRulesController do
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

    it "should create the correct rule and assign an override group if specified" do
      group = Factory(:group)
      u = Factory(:admin_user)
      sign_in_as u
      post :create, 
            business_validation_template_id: @bvt.id, 
            business_validation_rule: {
              "rule_attributes_json" => '{"valid":"json-2"}',
              "type" => "ValidationRuleManual",
              "group_id" => group.id
            }
      expect(response).to be_redirect
      new_rule = BusinessValidationRule.last
      expect(new_rule.business_validation_template.id).to eq(@bvt.id)
      expect(new_rule.rule_attributes_json).to eq('{"valid":"json-2"}')
      expect(new_rule.group).to eq group
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
      expect(flash[:errors].first).to match(/Could not save due to invalid JSON/)
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
      expect(response.request.filtered_parameters["id"].to_i).to eq(@bvr.id)
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
      expect(@bvr.search_criterions.length).to eq(1)
      expect(@bvr.search_criterions.first.value).to eq("Monica Lewinsky")
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
      expect(updated_rule.rule_attributes_json).to eq('{"valid":"json-4"}')
      expect(updated_rule.business_validation_template.id).to eq(@bvt.id)
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
      @u = Factory(:admin_user)
      sign_in_as @u
    end

    it 'should require admin' do
      @u.admin = false
      @u.save!
      post :destroy, id: @bvr.id, business_validation_template_id: @bvt.id
      expect_any_instance_of(BusinessValidationRule).not_to receive(:delay)
      expect(response).to be_redirect
    end

    it "should delete the correct rule" do
      dj_status = Delayed::Worker.delay_jobs
      Delayed::Worker.delay_jobs = false

      post :destroy, id: @bvr.id, business_validation_template_id: @bvt.id
      expect { BusinessValidationRule.find(@bvr.id) }.to raise_error

      Delayed::Worker.delay_jobs = dj_status
    end

    it "sets delete_pending flag and executes destroy as a delayed job" do
      d = double("delay")
      expect(BusinessValidationRule).to receive(:delay).and_return d
      expect(d).to receive(:async_destroy).with @bvr.id
      post :destroy, id: @bvr.id, business_validation_template_id: @bvt.id
      @bvr.reload
      expect(@bvr.delete_pending).to eq true
    end

  end

end
