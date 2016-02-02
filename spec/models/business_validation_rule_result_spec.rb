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
    before :each do
      @group = Factory(:group)
      @bvr = Factory(:business_validation_rule, group: @group)
      @bvrr = Factory(:business_validation_rule_result, business_validation_rule: @bvr)
    end

    it "should allow users who belong to rule's override group" do
      u = Factory(:user, groups: [@group])
      expect(@bvrr.can_edit?(u)).to be true
    end
    it "should allow users who are admins" do
      u = Factory(:admin_user)
      expect(@bvrr.can_edit?(u)).to be true
    end
    it "should not allow users who aren't admins or don't belong to rule's override group" do
      u = Factory(:user)
      expect(@bvrr.can_edit?(u)).to be false
    end
    it "should allow users who aren't admins if no group has been assigned" do
      u = Factory(:user)
      u.stub(:edit_business_validation_rule_results?).and_return true
      @bvr.group = nil
      @bvr.save!
      expect(@bvrr.can_edit?(u)).to be true
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

  describe "after_destroy" do
    before :each do
      @bvrr_1 = Factory(:business_validation_rule_result)
      @bvre = @bvrr_1.business_validation_result
    end

    it "should destroy parent object if destroyed and without siblings" do
      @bvrr_1.destroy
      expect(BusinessValidationResult.where(id: @bvre.id).count).to eq 0
    end

    it "should do nothing if destroyed with at least one sibling" do
      @bvrr_2 = Factory(:business_validation_rule_result, business_validation_result: @bvre)
      @bvrr_2.destroy
      expect(BusinessValidationResult.where(id: @bvre.id).count).to eq 1
    end
  end

  describe :cancel_override do
    it "should set overridden_at and overridden_by to nil" do
      u = User.new
      r = Factory(:business_validation_rule_result, overridden_at: Time.now, overridden_by: u)
      r.cancel_override
      expect(r.overridden_by).to eq nil
      expect(r.overridden_at).to eq nil
    end
  end
end
