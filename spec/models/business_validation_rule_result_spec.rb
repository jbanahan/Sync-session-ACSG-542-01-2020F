class MockBusinessValidationRule < BusinessValidationRule
  def run_validation(_obj); end
end

describe BusinessValidationRuleResult do
  describe "can_view" do
    it "allows users who can view results" do
      u = Factory(:master_user)
      u.company.update(show_business_rules: true)
      expect(described_class.new.can_view?(u)).to be_truthy
    end

    it "does not allow who can't view results" do
      u = Factory(:user)
      expect(described_class.new.can_view?(u)).to be_falsey
    end
  end

  describe "can_edit" do
    let(:group) { Factory(:group) }
    let(:business_validation_rule) { Factory(:business_validation_rule, group: group) }
    let(:business_validation_rule_result) { Factory(:business_validation_rule_result, business_validation_rule: business_validation_rule) }

    it "allows users who belong to rule's override group" do
      u = Factory(:user, groups: [group])
      expect(business_validation_rule_result.can_edit?(u)).to be true
    end

    it "allows users who are admins" do
      u = Factory(:admin_user)
      expect(business_validation_rule_result.can_edit?(u)).to be true
    end

    it "does not allow users who aren't admins or don't belong to rule's override group" do
      u = Factory(:user)
      expect(business_validation_rule_result.can_edit?(u)).to be false
    end

    it "allows users who aren't admins if no group has been assigned" do
      u = Factory(:user)
      allow(u).to receive(:edit_business_validation_rule_results?).and_return true
      business_validation_rule.group = nil
      business_validation_rule.save!
      expect(business_validation_rule_result.can_edit?(u)).to be true
    end
  end

  describe "run_validation" do
    it "sets failure state and message" do
      json = {model_field_uid: :ord_ord_num, regex: 'X.*Y'}.to_json
      vr = ValidationRuleFieldFormat.create!(name: "Name", description: "Description", rule_attributes_json: json, fail_state: 'x')
      expect(vr).to receive(:active?).and_return true
      rule = described_class.new
      rule.business_validation_rule = vr
      expect(rule.run_validation(Order.new)).to be_truthy
      expect(rule.state).to eq 'x'
      expect(rule.message).to eq vr.run_validation(Order.new)
    end

    it "returns 'true' if new state matches previous one but message has changed" do
      json = {model_field_uid: :ord_ord_num, regex: 'X.*Y'}.to_json
      vr = ValidationRuleFieldFormat.create!(name: "Name", description: "Description", rule_attributes_json: json, fail_state: 'x')
      expect(vr).to receive(:active?).and_return true
      rule = described_class.new state: 'x', message: 'original msg'
      rule.business_validation_rule = vr
      expect(rule.run_validation(Order.new)).to be_truthy
      expect(rule.state).to eq 'x'
      expect(rule.message).to eq vr.run_validation(Order.new)
    end

    it "defaults state to Fail if no fail_state" do
      json = {model_field_uid: :ord_ord_num, regex: 'X.*Y'}.to_json
      vr = ValidationRuleFieldFormat.create!(name: "Name", description: "Description", rule_attributes_json: json)
      expect(vr).to receive(:active?).and_return true
      rule = described_class.new
      expect(rule.business_validation_rule = vr).to be_truthy
      rule.run_validation(Order.new)
      expect(rule.state).to eq 'Fail'
    end

    it "defaults state to Fail if fail_state is blank" do
      json = {model_field_uid: :ord_ord_num, regex: 'X.*Y'}.to_json
      vr = ValidationRuleFieldFormat.create!(name: "Name", description: "Description", rule_attributes_json: json, fail_state: "")
      expect(vr).to receive(:active?).and_return true
      rule = described_class.new
      expect(rule.business_validation_rule = vr).to be_truthy
      rule.run_validation(Order.new)
      expect(rule.state).to eq 'Fail'
    end

    it "sets state to Pass if no fail message" do
      json = {model_field_uid: :ord_ord_num, regex: 'X.*Y'}.to_json
      vr = ValidationRuleFieldFormat.create!(name: "Name", description: "Description", rule_attributes_json: json, fail_state: 'x')
      expect(vr).to receive(:active?).and_return true
      rule = described_class.new
      rule.business_validation_rule = vr
      expect(rule.run_validation(Order.new(order_number: 'XabcY'))).to be_truthy
      expect(rule.state).to eq 'Pass'
      expect(rule.message).to be_nil
    end

    it "sets state to skipped if rule search_criterions aren't met" do
      json = {model_field_uid: :ord_ord_num, regex: 'X.*Y'}.to_json
      vr = ValidationRuleFieldFormat.create!(name: "Name", description: "Description", rule_attributes_json: json, fail_state: 'x')
      expect(vr).to receive(:active?).and_return true
      vr.search_criterions.create!(model_field_uid: :ord_ord_num, operator: 'eq', value: 'ZZ')
      rule = described_class.new
      rule.business_validation_rule = vr
      expect(rule.run_validation(Order.new(order_number: 'WouldFail'))).to be_truthy
      expect(rule.state).to eq 'Skipped'
      expect(rule.message).to be_nil
    end

    it "does not do anything if overridden_at is set" do
      json = {model_field_uid: :ord_ord_num, regex: 'X.*Y'}.to_json
      vr = ValidationRuleFieldFormat.create!(name: "Name", description: "Description", rule_attributes_json: json)
      rule = described_class.new
      rule.business_validation_rule = vr
      rule.overridden_at = Time.zone.now
      rule.state = 'X'
      expect(rule.run_validation(Order.new)).to be_falsey
      expect(rule.state).to eq 'X'
    end

    it "does not do anything if validation rule is inactive" do
      json = {model_field_uid: :ord_ord_num, regex: 'X.*Y'}.to_json
      vr = ValidationRuleFieldFormat.create!(name: "Name", description: "Description", rule_attributes_json: json)
      expect(vr).to receive(:active?).and_return false
      rule = Factory(:business_validation_rule_result)
      rule.business_validation_rule = vr
      rule.state = 'X'
      rule.business_validation_rule.save!
      rule.save!
      expect(rule.run_validation(Order.new)).to be_falsey
      expect(rule.state).to eq 'X'
    end

    context "mocked business_validation_rule" do
      let(:object) { Object.new }

      let!(:rule) do
        d = instance_double(MockBusinessValidationRule)
        allow(subject).to receive(:business_validation_rule).and_return d
        allow(d).to receive(:active?).and_return true
        allow(d).to receive(:should_skip?).and_return false
        allow(d).to receive(:fail_state).and_return "Failure"

        d
      end

      it "allows returning arrays of messages to indicate failure" do
        expect(rule).to receive(:run_validation).with(object).and_return ["Failure"]

        expect(subject.run_validation(object)).to eq true
        expect(subject.state).to eq "Failure"
      end

      it "allows returning arrays with multiple messages to indicate failure" do
        expect(rule).to receive(:run_validation).with(object).and_return ["Failure 1", "Failure 2"]

        expect(subject.run_validation(object)).to eq true
        expect(subject.message).to eq "Failure 1\nFailure 2"
        expect(subject.state).to eq "Failure"
      end

      it "handles blank arrays as not a failure" do
        expect(rule).to receive(:run_validation).with(object).and_return []
        expect(subject.run_validation(object)).to eq true
        expect(subject.state).to eq "Pass"
      end

      it "allows returning of strings to indicate failure" do
        expect(rule).to receive(:run_validation).with(object).and_return "Failure"

        expect(subject.run_validation(object)).to eq true
        expect(subject.state).to eq "Failure"
      end

      it "handles blank string as not a failure" do
        expect(rule).to receive(:run_validation).with(object).and_return ""
        expect(subject.run_validation(object)).to eq true
        expect(subject.state).to eq "Pass"
      end

      it "handles nil as not a failure" do
        expect(rule).to receive(:run_validation).with(object).and_return nil
        expect(subject.run_validation(object)).to eq true
        expect(subject.state).to eq "Pass"
      end
    end
  end

  describe "run_validation_with_state_tracking" do

    subject do
      r = described_class.new
      r.id = 1
      r
    end

    it "wraps run_validation in state tracking" do
      obj = Object.new
      expect(subject).to receive(:state).ordered.and_return "State 1"
      expect(subject).to receive(:state).ordered.and_return "State 2"
      expect(subject).to receive(:run_validation).with(obj).and_return true

      expect(subject.run_validation_with_state_tracking(obj)).to eq({id: 1, changed: true, new_state: "State 2", old_state: "State 1"})
    end
  end

  describe "override" do
    it "sets overriden_at and overriden_by" do
      u = User.new
      r = described_class.new
      r.override u
      expect(r.overridden_by).to eq u
      expect(r.overridden_at).to be <= Time.zone.now
    end
  end

  describe "after_destroy" do
    let(:business_validation_rule_result) { Factory(:business_validation_rule_result) }
    let(:business_validation_result) { business_validation_rule_result.business_validation_result }

    it "destroys parent object if destroyed and without siblings" do
      business_validation_rule_result.destroy
      expect(BusinessValidationResult.where(id: business_validation_result.id).count).to eq 0
    end

    it "does nothing if destroyed with at least one sibling" do
      bvrr_2 = Factory(:business_validation_rule_result, business_validation_result: business_validation_result)
      bvrr_2.destroy
      expect(BusinessValidationResult.where(id: business_validation_result.id).count).to eq 1
    end
  end

  describe "cancel_override" do
    it "sets overridden_at, overridden_by, and note to nil" do
      u = User.new
      r = Factory(:business_validation_rule_result, overridden_at: Time.zone.now, overridden_by: u, note: "Some message.")
      r.cancel_override
      expect(r.overridden_by).to eq nil
      expect(r.overridden_at).to eq nil
      expect(r.note).to eq nil
    end
  end
end
