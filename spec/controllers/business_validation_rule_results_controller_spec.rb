describe BusinessValidationRuleResultsController do

  let(:user) do
    au = create(:admin_user)
    au.company.update(show_business_rules: true)
    au
  end

  let(:entry) { create(:entry, broker_reference: "REF") }

  before do
    sign_in_as user

    t = BusinessValidationTemplate.create! name: "Test", module_type: "Entry", description: "Test Template"
    t.search_criterions.create! model_field_uid: "ent_brok_ref", operator: "notnull"
    t.business_validation_rules.create! type: "ValidationRuleFieldFormat", name: "Broker Reference", description: "Rule Description",
                                        rule_attributes_json: {model_field_uid: "ent_brok_ref", regex: "ABC"}.to_json

    BusinessValidationTemplate.create_results_for_object! entry
  end

  describe "update" do

    let(:rule_result) { entry.business_validation_results.first.business_validation_rule_results.first }

    it "overrides rule result data" do
      now = Time.zone.now
      Timecop.freeze(now) do
        put :update, id: rule_result.id, business_validation_rule_result: {note: 'abc', state: 'Pass'}, format: :json
      end

      h = JSON.parse(response.body)['save_response']
      expect(h['result_state']).to eq 'Pass'
      rr = h['rule_result']
      expect(rr['id']).to eq rule_result.id
      expect(rr['state']).to eq 'Pass'
      expect(rr['rule']['name']).to eq 'Broker Reference'
      expect(rr['note']).to eq 'abc'
      expect(rr['overridden_by']['full_name']).to eq user.full_name
      expect(rr['overridden_at']).to eq json_date(now)
    end

    it "denies access to users who cannot edit rule results" do
      expect_any_instance_of(BusinessValidationRuleResult).to receive(:can_edit?).with(user).and_return(false)
      put :update, id: rule_result.id, business_validation_rule_result: {note: 'abc', state: 'Pass'}
      expect(response).to be_redirect
      rule_result.reload
      expect(rule_result.note).to be_nil
      expect(rule_result.state).to eq 'Fail'
    end

    it "allows using html format to update rule data" do
      put :update, id: rule_result.id, business_validation_rule_result: {note: 'abc', state: 'Pass'}
      expect(response).to redirect_to "/entries/#{entry.id}/validation_results"
      entry.business_validation_results.reload
      expect(entry.business_validation_results.first.state).to eq 'Pass'
    end

    it "sanitizes params and only allows updating state and note values" do
      rule_result.update message: "xyz"

      put :update, id: rule_result.id, business_validation_rule_result: {note: 'abc', state: 'Pass', message: 'qrs'}

      rule_result.reload
      expect(rule_result.note).to eq 'abc'
      expect(rule_result.state).to eq 'Pass'
      expect(rule_result.message).to eq 'xyz'
    end
  end

  describe "cancel_override" do
    let(:rule_result) { entry.business_validation_results.first.business_validation_rule_results.first }

    before do
      rule_result.update(overridden_at: Time.zone.now, overridden_by: user, note: "Some message.")
    end

    it "does not not allow users without edit to cancel overrides" do
      expect_any_instance_of(BusinessValidationRuleResult).to receive(:can_edit?).with(user).and_return(false)
      expect(BusinessValidationTemplate).not_to receive(:create_results_for_object!)
      put :cancel_override, id: rule_result.id

      rule_result.reload

      expect(rule_result.overridden_at).not_to be nil
      expect(rule_result.overridden_by).not_to be nil
      expect(rule_result.note).not_to be nil
      expect(JSON.parse(response.body)["error"]).to eq "You do not have permission to perform this activity."
    end

    it "clears overridden attributes and note, reruns validations for the result's validatable" do
      expect(BusinessValidationTemplate).to receive(:create_results_for_object!).with(entry)
      put :cancel_override, id: rule_result.id
      rule_result.reload

      expect(rule_result.overridden_at).to be_nil
      expect(rule_result.overridden_by).to be_nil
      expect(rule_result.note).to be_nil
      expect(flash[:errors]).to be_blank
      expect(JSON.parse(response.body)["ok"]).to eq "ok"
    end
  end
end
