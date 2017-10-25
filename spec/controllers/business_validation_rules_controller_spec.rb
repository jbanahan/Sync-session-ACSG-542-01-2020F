require 'spec_helper'

describe BusinessValidationRulesController do
  describe "create" do
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

  describe "edit" do
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

  describe "update" do
    before :each do
      @bvr = Factory(:business_validation_rule)
      @bvt = @bvr.business_validation_template
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
              search_criterions: [{"mfid" => "ent_cust_name",
                                   "datatype" => "string", "label" => "Customer Name",
                                   "operator" => "eq", "value" => "Monica Lewinsky"}],
             rule_attributes_json: '{"valid":"json-4"}',
             description: "descr",
             fail_state: "Fail",
             group_id: 1,
             notification_type: "Email",
             notification_recipients: "tufnel@stonehenge.biz"}
              
      expect(JSON.parse response.body).to eq({"notice" => "Business rule updated"})
      @bvr.reload
      expect(@bvr.rule_attributes_json).to eq('{"valid":"json-4"}')
      expect(@bvr.search_criterions.first.value).to eq("Monica Lewinsky")
      expect(@bvr.rule_attributes_json).to eq('{"valid":"json-4"}')
      expect(@bvr.description).to eq('descr')
      expect(@bvr.fail_state).to eq('Fail')
      expect(@bvr.group_id).to eq(1)
      expect(@bvr.notification_type).to eq("Email")
      expect(@bvr.notification_recipients).to eq("tufnel@stonehenge.biz")
      expect(@bvr.business_validation_template.id).to eq(@bvt.id)
    end

    it "errors if json is invalid" do
      u = Factory(:admin_user)
      sign_in_as u
      post :update,
            id: @bvr.id,
            business_validation_template_id: @bvt.id,
            business_validation_rule: { 
              search_criterions: [{"mfid" => "ent_cust_name",
                                   "datatype" => "string", "label" => "Customer Name",
                                   "operator" => "eq", "value" => "Monica Lewinsky"}],
             name: "foo",
             rule_attributes_json: '{"valid":"json-4"',
             }
       expect(JSON.parse response.body).to eq({"error" => "Could not save due to invalid JSON."})
       expect(response.status).to eq 500
       expect(@bvr.search_criterions.count).to be_zero
       expect(@bvr.name).to be_nil
    end

  end

  describe "edit_angular" do
    before :each do
      @sc = Factory(:search_criterion)
      # Use an actual concrete rule class rather than the base 'abstract' class to validate we're getting the correct data back
      # since there's some handling required in these cases
      @bvt = Factory(:business_validation_template)
      @group = Factory(:group)
      @rule = ValidationRuleAttachmentTypes.new description: "DESC", fail_state: "FAIL", name: "NAME", disabled: false, group_id: @group.id, rule_attributes_json: '{"test":"testing"}', notification_type: "Email", notification_recipients: "tufnel@stonehenge.biz"
      @rule.search_criterions << @sc
      @rule.business_validation_template = @bvt
      @rule.save!
    end

    it "should render the correct model_field and business_rule json" do
      u = Factory(:admin_user)
      sign_in_as u
      get :edit_angular, id: @rule.id 
      r = JSON.parse(response.body)
      expect(r["model_fields"].length).to eq(CoreModule::ENTRY.default_module_chain.model_fields(u).values.size)
      rule = r["business_validation_rule"]
      expect(rule).to eq({"business_validation_template_id"=>@bvt.id,
          "description"=>"DESC", "fail_state"=>"FAIL", "disabled" => false, "id"=>@rule.id, "group_id"=>@group.id, "type"=>"ValidationRuleAttachmentTypes",
          "name"=>"NAME", "rule_attributes_json"=>'{"test":"testing"}', "notification_type" => "Email", "notification_recipients" => "tufnel@stonehenge.biz",
          "search_criterions"=>[{"mfid"=>"prod_uid", "operator"=>"eq", "value"=>"x", "label" => "Unique Identifier", "datatype" => "string", "include_empty" => false}]})
    end

    it 'should require admin' do
      u = Factory(:user)
      sign_in_as u
      get :edit_angular, id: @rule.id
      expect(response).to be_redirect
    end
  end

  describe "destroy" do
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
      expect_any_instance_of(BusinessValidationRule).not_to receive(:destroy)
      expect(response).to be_redirect
    end

    it "should delete the correct rule" do
      post :destroy, id: @bvr.id, business_validation_template_id: @bvt.id
      expect(BusinessValidationRule.find_by_id(@bvr.id)).to be_nil
    end

  end

end
