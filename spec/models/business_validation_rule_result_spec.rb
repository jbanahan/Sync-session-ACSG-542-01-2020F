require 'spec_helper'

describe BusinessValidationRuleResult do
  describe :can_view do
    it "should allow users who can view results" do
      u = Factory(:master_user)
      expect(described_class.new.can_view?(u)).to be_true
    end
    it "should not allow who can't view results" do
      u = Factory(:user)
      expect(described_class.new.can_view?(u)).to be_false
    end
  end
  describe :can_edit do
    it "should allow users from master company" do
      u = Factory(:master_user)
      expect(described_class.new.can_edit?(u)).to be_true
    end
    it "should not allow users not from master company" do
      u = Factory(:user)
      expect(described_class.new.can_edit?(u)).to be_false
    end
  end
  describe :run_validation do
    it "should set failure state and message" do
      json = {model_field_uid: :ord_ord_num, regex:'X.*Y'}.to_json
      vr = ValidationRuleFieldFormat.create!(rule_attributes_json:json,fail_state:'x')
      rule = BusinessValidationRuleResult.new
      rule.business_validation_rule = vr
      rule.run_validation(Order.new)
      expect(rule.state).to eq 'x'
      expect(rule.message).to eq vr.run_validation(Order.new)
    end
    it "should default state to Fail if no fail_state" do
      json = {model_field_uid: :ord_ord_num, regex:'X.*Y'}.to_json
      vr = ValidationRuleFieldFormat.create!(rule_attributes_json:json)
      rule = BusinessValidationRuleResult.new
      rule.business_validation_rule = vr
      rule.run_validation(Order.new)
      expect(rule.state).to eq 'Fail'
    end
    it "should set state to Pass if no fail message" do
      json = {model_field_uid: :ord_ord_num, regex:'X.*Y'}.to_json
      vr = ValidationRuleFieldFormat.create!(rule_attributes_json:json,fail_state:'x')
      rule = BusinessValidationRuleResult.new
      rule.business_validation_rule = vr
      rule.run_validation(Order.new(order_number:'XabcY'))
      expect(rule.state).to eq 'Pass'
      expect(rule.message).to be_nil
    end
    it "should set state to skipped if rule search_criterions aren't met" do
      json = {model_field_uid: :ord_ord_num, regex:'X.*Y'}.to_json
      vr = ValidationRuleFieldFormat.create!(rule_attributes_json:json,fail_state:'x')
      vr.search_criterions.create!(model_field_uid: :ord_ord_num, operator: 'eq', value:'ZZ')
      rule = BusinessValidationRuleResult.new
      rule.business_validation_rule = vr
      rule.run_validation(Order.new(order_number:'WouldFail'))
      expect(rule.state).to eq 'Skipped'
      expect(rule.message).to be_nil
    end
    it "should not do anything if overridden_at is set" do
      json = {model_field_uid: :ord_ord_num, regex:'X.*Y'}.to_json
      vr = ValidationRuleFieldFormat.create!(rule_attributes_json:json)
      rule = BusinessValidationRuleResult.new
      rule.business_validation_rule = vr
      rule.overridden_at = Time.now
      rule.state = 'X'
      rule.run_validation(Order.new)
      expect(rule.state).to eq 'X'
    end
  end
  describe :override do
    it "should set overriden_at and overriden_by" do
      u = User.new
      r = described_class.new
      r.override u
      expect(r.overridden_by).to eq u
      expect(r.overridden_at).to be <= Time.now
    end
  end
end
