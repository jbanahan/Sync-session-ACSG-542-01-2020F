describe BusinessValidationRulesController do
  describe "create" do
    let(:business_validation_rule) { create(:business_validation_rule) }
    let(:business_validation_template) { business_validation_rule.business_validation_template }

    it 'requires admin' do
      u = create(:user)
      sign_in_as u
      post :create,
           business_validation_template_id: business_validation_template.id,
           business_validation_rule: {
             "rule_attributes_json" => '{"valid":"json-1"}'
           }
      expect(response).to be_redirect
    end

    it "creates the correct rule and assign an override group if specified" do
      group = create(:group)
      u = create(:admin_user)
      sign_in_as u
      post :create,
           business_validation_template_id: business_validation_template.id,
           business_validation_rule: {
             "rule_attributes_json" => '{"valid":"json-2"}',
             "type" => "ValidationRuleManual",
             "group_id" => group.id,
             "name" => "Name",
             "description" => "Description"
           }
      expect(response).to be_redirect
      new_rule = BusinessValidationRule.last
      expect(new_rule.business_validation_template.id).to eq(business_validation_template.id)
      expect(new_rule.rule_attributes_json).to eq('{"valid":"json-2"}')
      expect(new_rule.group).to eq group
    end

    it "onlies save for valid JSON" do
      u = create(:admin_user)
      sign_in_as u
      post :create,
           business_validation_template_id: business_validation_template.id,
           business_validation_rule: {
             "rule_attributes_json" => 'This is not valid JSON'
           }
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/Could not save due to invalid JSON/)
    end

    it "only saves for valid bccs (when applicable)" do
      u = create(:admin_user)
      sign_in_as u
      post :create,
           business_validation_template_id: business_validation_template.id,
           business_validation_rule: {
             "rule_attributes_json" => '{"valid":"json-2"}',
             "type" => "ValidationRuleManual",
             "bcc_notification_recipients" => "tufnel@ston'ehenge.biz"
           }
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/Could not save due to invalid BCC email/)
    end

    it "only saves for valid ccs (when applicable)" do
      u = create(:admin_user)
      sign_in_as u
      post :create,
           business_validation_template_id: business_validation_template.id,
           business_validation_rule: {
             "rule_attributes_json" => '{"valid":"json-2"}',
             "type" => "ValidationRuleManual",
             "cc_notification_recipients" => "tufnel@ston'ehenge.biz"
           }
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/Could not save due to invalid CC email/)
    end

    it "only saves for valid email (when applicable)" do
      u = create(:admin_user)
      sign_in_as u
      post :create,
           business_validation_template_id: business_validation_template.id,
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
    let(:business_validation_rule) { create(:business_validation_rule) }
    let(:business_validation_template) { business_validation_rule.business_validation_template }

    it 'requires admin' do
      u = create(:user)
      sign_in_as u
      get :edit, id: business_validation_rule.id, business_validation_template_id: business_validation_template.id
      expect(response).to be_redirect
    end

    it "loads the correct rule to edit" do
      u = create(:admin_user)
      sign_in_as u
      get :edit,
          id: business_validation_rule.id,
          business_validation_template_id: business_validation_template.id,
          business_validation_rule: {
            "rule_attributes_json" => '{"valid":"json-3"}'
          }
      expect(response).to be_success
      expect(response.request.filtered_parameters["id"].to_i).to eq(business_validation_rule.id)
    end

  end

  describe "update" do
    let(:business_validation_rule) { create(:business_validation_rule) }
    let(:business_validation_template) { business_validation_rule.business_validation_template }

    it 'requires admin' do
      u = create(:user)
      sign_in_as u
      post :update, id: business_validation_rule.id, business_validation_template_id: business_validation_template.id
      expect(response).to be_redirect
    end

    it "updates the correct rule" do
      u = create(:admin_user)
      group_id = create(:group).id
      sign_in_as u
      post :update,
           id: business_validation_rule.id,
           business_validation_template_id: business_validation_template.id,
           business_validation_rule: {
             search_criterions: [{"mfid" => "ent_cust_name",
                                  "datatype" => "string", "label" => "Customer Name",
                                  "operator" => "eq", "value" => "Joel Zimmerman"}],
             rule_attributes_json: '{"valid":"json-4"}',
             description: "descr",
             fail_state: "Fail",
             group_id: group_id,
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
             message_skipped: "this rule was skipped"
           }

      expect(JSON.parse(response.body)).to eq({"notice" => "Business rule updated"})
      business_validation_rule.reload
      expect(business_validation_rule.rule_attributes_json).to eq('{"valid":"json-4"}')
      expect(business_validation_rule.search_criterions.first.value).to eq("Joel Zimmerman")
      expect(business_validation_rule.rule_attributes_json).to eq('{"valid":"json-4"}')
      expect(business_validation_rule.description).to eq('descr')
      expect(business_validation_rule.fail_state).to eq('Fail')
      expect(business_validation_rule.group_id).to eq(group_id)
      expect(business_validation_rule.notification_type).to eq("Email")
      expect(business_validation_rule.notification_recipients).to eq("tufnel@stonehenge.biz")
      expect(business_validation_rule.suppress_pass_notice).to eq true
      expect(business_validation_rule.suppress_review_fail_notice).to eq true
      expect(business_validation_rule.suppress_skipped_notice).to eq true
      expect(business_validation_rule.subject_pass).to eq "subject - PASS"
      expect(business_validation_rule.subject_review_fail).to eq "subject - FAIL"
      expect(business_validation_rule.subject_skipped).to eq "subject - SKIPPED"
      expect(business_validation_rule.message_pass).to eq "this rule passed"
      expect(business_validation_rule.message_review_fail).to eq "this rule failed"
      expect(business_validation_rule.message_skipped).to eq "this rule was skipped"

      expect(business_validation_rule.business_validation_template.id).to eq(business_validation_template.id)
    end

    it "errors if json is invalid" do
      u = create(:admin_user)
      sign_in_as u
      post :update,
           id: business_validation_rule.id,
           business_validation_template_id: business_validation_template.id,
           business_validation_rule: {
             search_criterions: [{"mfid" => "ent_cust_name",
                                  "datatype" => "string", "label" => "Customer Name",
                                  "operator" => "eq", "value" => "Joel Zimmerman",
                                  "name" => "Name", "description" => "Description"}],
             name: "foo",
             rule_attributes_json: '{"valid":"json-4"'
           }
      expect(JSON.parse(response.body)).to eq({"error" => "Could not save due to invalid JSON."})
      expect(response.status).to eq 500
      expect(business_validation_rule.search_criterions.count).to be_zero
      expect(business_validation_rule.name).not_to eql("foo")
    end

    it "errors if email is invalid (when applicable)" do
      u = create(:admin_user)
      sign_in_as u
      post :update,
           id: business_validation_rule.id,
           business_validation_template_id: business_validation_template.id,
           business_validation_rule: {
             notification_recipients: "tufnel@stone'henge.biz"
           }
      expect(JSON.parse(response.body)).to eq({"error" => "Could not save due to invalid email."})
      expect(response.status).to eq 500
      expect(business_validation_rule.notification_recipients).to be_nil
    end

  end

  describe "edit_angular" do
    let!(:search_criterion) { create(:search_criterion) }
    let!(:business_validation_template) { create(:business_validation_template) }
    let!(:group) { create(:group) }

    let!(:rule) do
      rule = ValidationRuleAttachmentTypes.new description: "DESC", fail_state: "FAIL", name: "NAME", disabled: false,
                                               group_id: group.id, rule_attributes_json: '{"test":"testing"}',
                                               notification_type: "Email", notification_recipients: "tufnel@stonehenge.biz",
                                               suppress_pass_notice: true, suppress_review_fail_notice: true,
                                               suppress_skipped_notice: true, subject_pass: "subject - PASS",
                                               subject_review_fail: "subject - FAIL", subject_skipped: "subject - SKIPPED",
                                               message_pass: "this rule passed", message_review_fail: "this rule failed",
                                               message_skipped: "this rule was skipped"
      rule.search_criterions << search_criterion
      rule.business_validation_template = business_validation_template
      rule.save!
      rule
    end

    it "renders the correct model_field and business_rule json" do
      u = create(:admin_user)
      sign_in_as u
      get :edit_angular, id: rule.id
      r = JSON.parse(response.body)
      expect(r["model_fields"].length).to eq(CoreModule::ENTRY.default_module_chain.model_fields(u).values.size)
      rule_hash = r["business_validation_rule"]
      expect(rule_hash).to eq({"mailing_lists" => [], "business_validation_template_id" => business_validation_template.id,
                               "mailing_list_id" => nil, "description" => "DESC", "fail_state" => "FAIL", "disabled" => false,
                               "id" => rule.id, "group_id" => group.id, "type" => "Has Attachment Types", "name" => "NAME",
                               "rule_attributes_json" => '{"test":"testing"}', "notification_type" => "Email",
                               "notification_recipients" => "tufnel@stonehenge.biz", "suppress_pass_notice" => true,
                               "suppress_review_fail_notice" => true, "suppress_skipped_notice" => true,
                               "subject_pass" => "subject - PASS", "subject_review_fail" => "subject - FAIL",
                               "subject_skipped" => "subject - SKIPPED", "message_pass" => "this rule passed",
                               "message_review_fail" => "this rule failed", "message_skipped" => "this rule was skipped",
                               "search_criterions" => [{"mfid" => "prod_uid", "operator" => "eq", "value" => "x",
                                                        "label" => "Unique Identifier", "datatype" => "string",
                                                        "include_empty" => false}]})
    end

    it 'requires admin' do
      u = create(:user)
      sign_in_as u
      get :edit_angular, id: rule.id
      expect(response).to be_redirect
    end
  end

  describe "destroy" do
    let(:business_validation_rule) { create(:business_validation_rule) }
    let(:business_validation_template) { business_validation_rule.business_validation_template }
    let(:user) { create(:admin_user) }

    before do
      sign_in_as user
    end

    it 'requires admin' do
      user.admin = false
      user.save!
      post :destroy, id: business_validation_rule.id, business_validation_template_id: business_validation_template.id
      expect_any_instance_of(BusinessValidationRule).not_to receive(:destroy)
      expect(response).to be_redirect
    end

    it "deletes the correct rule" do
      post :destroy, id: business_validation_rule.id, business_validation_template_id: business_validation_template.id
      expect(BusinessValidationRule.find_by(id: business_validation_rule.id)).to be_nil
    end
  end

  describe "upload", :disable_delayed_jobs do
    let(:user) { create(:admin_user) }
    let(:file) { instance_double("file") }
    let(:cf) { instance_double("custom file") }
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
      user = create(:user)
      sign_in_as user
      expect(CustomFile).not_to receive(:create!)
    end

    it "errors if no file submitted" do
      put :upload, attached: nil, business_validation_template_id: 2
      expect(CustomFile).not_to receive(:create!)
      expect(flash[:errors]).to include "You must select a file to upload."
    end
  end

  describe "copy", :disable_delayed_jobs do
    let(:user) { create(:admin_user) }
    let(:bvt) { create(:business_validation_template) }
    let(:bvru) { create(:business_validation_rule) }

    before { sign_in_as user }

    it "copies business rule to specified template" do
      expect(OpenChain::BusinessRulesCopier).to receive(:copy_rule).with(user.id, bvru.id, bvt.id)
      post :copy, business_validation_template_id: bvt.id, id: bvru.id, new_template_id: bvt.id
      expect(response).to redirect_to(edit_business_validation_template_path(bvt))
      expect(flash[:notices]).to include "Business Validation Rule is being copied. You'll receive a " + MasterSetup.application_name + " message when it completes."
    end

    it "requires admin" do
      user = create(:user)
      sign_in_as user
      expect(OpenChain::BusinessRulesCopier).not_to receive(:copy_rule)
      post :copy, business_validation_template_id: bvt.id, id: bvru.id, new_template_id: bvt.id
    end
  end

end
