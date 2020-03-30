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
              "group_id" => group.id,
              "name" => "Name",
              "description" => "Description"
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

    it "only saves for valid bccs (when applicable)" do
      u = Factory(:admin_user)
      sign_in_as u
      post :create,
           business_validation_template_id: @bvt.id,
           business_validation_rule: {
               "rule_attributes_json" => '{"valid":"json-2"}',
               "type" => "ValidationRuleManual",
               "bcc_notification_recipients" => "tufnel@ston'ehenge.biz"
           }
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/Could not save due to invalid BCC email/)
    end

    it "only saves for valid ccs (when applicable)" do
      u = Factory(:admin_user)
      sign_in_as u
      post :create,
           business_validation_template_id: @bvt.id,
           business_validation_rule: {
               "rule_attributes_json" => '{"valid":"json-2"}',
               "type" => "ValidationRuleManual",
               "cc_notification_recipients" => "tufnel@ston'ehenge.biz"
           }
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/Could not save due to invalid CC email/)
    end

    it "only saves for valid email (when applicable)" do
      u = Factory(:admin_user)
      sign_in_as u
      post :create,
            business_validation_template_id: @bvt.id,
            business_validation_rule: {
              "rule_attributes_json" => '{"valid":"json-2"}',
              "type" => "ValidationRuleManual",
              "notification_recipients" => "tufnel@ston'ehenge.biz"
            }
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/Could not save due to invalid email/)
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
                                   "operator" => "eq", "value" => "Joel Zimmerman"}],
              rule_attributes_json: '{"valid":"json-4"}',
              description: "descr",
              fail_state: "Fail",
              group_id: 1,
              notification_type: "Email",
              notification_recipients: "tufnel@stonehenge.biz",
              suppress_pass_notice: true,
              suppress_review_fail_notice: true,
              suppress_skipped_notice: true,
              subject_pass: "subject - PASS",
              subject_review_fail: "subject - FAIL",
              subject_skipped: "subject - SKIPPED",
              message_pass: "this rule passed",
              message_review_fail: "this rule failed",
              message_skipped: "this rule was skipped"}
              
      expect(JSON.parse response.body).to eq({"notice" => "Business rule updated"})
      @bvr.reload
      expect(@bvr.rule_attributes_json).to eq('{"valid":"json-4"}')
      expect(@bvr.search_criterions.first.value).to eq("Joel Zimmerman")
      expect(@bvr.rule_attributes_json).to eq('{"valid":"json-4"}')
      expect(@bvr.description).to eq('descr')
      expect(@bvr.fail_state).to eq('Fail')
      expect(@bvr.group_id).to eq(1)
      expect(@bvr.notification_type).to eq("Email")
      expect(@bvr.notification_recipients).to eq("tufnel@stonehenge.biz")
      expect(@bvr.suppress_pass_notice).to eq true
      expect(@bvr.suppress_review_fail_notice).to eq true
      expect(@bvr.suppress_skipped_notice).to eq true
      expect(@bvr.subject_pass).to eq "subject - PASS"
      expect(@bvr.subject_review_fail).to eq "subject - FAIL"
      expect(@bvr.subject_skipped).to eq "subject - SKIPPED"
      expect(@bvr.message_pass).to eq "this rule passed"
      expect(@bvr.message_review_fail).to eq "this rule failed"
      expect(@bvr.message_skipped).to eq "this rule was skipped"

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
                                   "operator" => "eq", "value" => "Joel Zimmerman",
                                   "name" => "Name", "description" => "Description"
                                  }],
             name: "foo",
             rule_attributes_json: '{"valid":"json-4"',
             }
       expect(JSON.parse response.body).to eq({"error" => "Could not save due to invalid JSON."})
       expect(response.status).to eq 500
       expect(@bvr.search_criterions.count).to be_zero
       expect(@bvr.name).to_not eql("foo")
    end

    it "errors if email is invalid (when applicable)" do
      u = Factory(:admin_user)
      sign_in_as u
      post :update,
            id: @bvr.id,
            business_validation_template_id: @bvt.id,
            business_validation_rule: { 
             notification_recipients: "tufnel@stone'henge.biz"
             }
       expect(JSON.parse response.body).to eq({"error" => "Could not save due to invalid email."})
       expect(response.status).to eq 500
       expect(@bvr.notification_recipients).to be_nil
    end

  end

  describe "edit_angular" do
    before :each do
      @sc = Factory(:search_criterion)
      # Use an actual concrete rule class rather than the base 'abstract' class to validate we're getting the correct data back
      # since there's some handling required in these cases
      @bvt = Factory(:business_validation_template)
      @group = Factory(:group)
      @rule = ValidationRuleAttachmentTypes.new description: "DESC", fail_state: "FAIL", name: "NAME", disabled: false, group_id: @group.id, 
                                                rule_attributes_json: '{"test":"testing"}', notification_type: "Email", notification_recipients: "tufnel@stonehenge.biz",
                                                suppress_pass_notice: true, suppress_review_fail_notice: true, suppress_skipped_notice: true, subject_pass: "subject - PASS",
                                                subject_review_fail: "subject - FAIL", subject_skipped: "subject - SKIPPED", message_pass: "this rule passed",
                                                message_review_fail: "this rule failed", message_skipped: "this rule was skipped"
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
      expect(rule).to eq({"mailing_lists"=>[],"business_validation_template_id"=>@bvt.id, "mailing_list_id"=>nil,
          "description"=>"DESC", "fail_state"=>"FAIL", "disabled" => false, "id"=>@rule.id, "group_id"=>@group.id, "type"=>"Has Attachment Types",
          "name"=>"NAME", "rule_attributes_json"=>'{"test":"testing"}', "notification_type" => "Email", "notification_recipients" => "tufnel@stonehenge.biz",
          "suppress_pass_notice"=> true, "suppress_review_fail_notice" => true, "suppress_skipped_notice" => true, "subject_pass" => "subject - PASS", "subject_review_fail" => "subject - FAIL",
          "subject_skipped" => "subject - SKIPPED", "message_pass" => "this rule passed", "message_review_fail" => "this rule failed", "message_skipped" => "this rule was skipped",
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

  describe "upload", :disable_delayed_jobs do
    let(:user) { Factory(:admin_user) }
    let(:file) { double "file"}
    let(:cf) { double "custom file" }
    let(:uploader) { OpenChain::BusinessRulesCopier::RuleUploader }
    before { sign_in_as user }

    it "processes file with rule copier" do
      allow(cf).to receive(:id).and_return 1
      expect(CustomFile).to receive(:create!).with(file_type: uploader.to_s, uploaded_by: user, attached: file.to_s).and_return cf
      expect(CustomFile).to receive(:process).with(1, user.id, bvt_id: '2')
      put :upload, attached: file, business_validation_template_id: 2
      expect(response).to redirect_to business_validation_template_path(2)
      expect(flash[:notices]).to include "Your file is being processed. You'll receive a " + MasterSetup.application_name + " message when it completes."
    end

    it "only allows admin" do
      user = Factory(:user)
      sign_in_as user
      expect(CustomFile).to_not receive(:create!)
    end

    it "errors if no file submitted" do
      put :upload, attached: nil, business_validation_template_id: 2
      expect(CustomFile).to_not receive(:create!)
      expect(flash[:errors]).to include "You must select a file to upload."
    end
  end

  describe "copy", :disable_delayed_jobs do
    let(:user) { Factory(:admin_user) }
    let(:bvt) { Factory(:business_validation_template) }
    let(:bvru) { Factory(:business_validation_rule) }

    before { sign_in_as user }

    it "copies business rule to specified template" do
      expect(OpenChain::BusinessRulesCopier).to receive(:copy_rule).with(user.id, bvru.id, bvt.id)
      post :copy, business_validation_template_id: bvt.id, id: bvru.id, new_template_id: bvt.id
      expect(response).to redirect_to(edit_business_validation_template_path bvt)
      expect(flash[:notices]).to include "Business Validation Rule is being copied. You'll receive a " + MasterSetup.application_name + " message when it completes."
    end

    it "requires admin" do
      user = Factory(:user)
      sign_in_as user
      expect(OpenChain::BusinessRulesCopier).to_not receive(:copy_rule)
      post :copy, business_validation_template_id: bvt.id, id: bvru.id, new_template_id: bvt.id
    end
  end

end
