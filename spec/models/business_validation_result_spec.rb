require 'spec_helper'

describe BusinessValidationResult do
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
    it "should set state to worst of rule results" do
      o = Order.new
      rr1 = BusinessValidationRuleResult.new
      rr2 = BusinessValidationRuleResult.new
      rr3 = BusinessValidationRuleResult.new
      rr4 = BusinessValidationRuleResult.new

      rr1.state = 'Pass'
      rr2.state = 'Fail'
      rr3.state = 'Review'
      rr4.state = 'Skipped'
      
      bvr = described_class.new
      bvr.validatable = o

      [rr1,rr2,rr3,rr4].each do |x|
        bvr.business_validation_rule_results << x
        x.should_receive(:run_validation).with(o)
      end

      bvr.run_validation
      expect(bvr.state).to eq 'Fail'
    end
    it "should pass if all rules pass" do
      o = Order.new
      rr1 = BusinessValidationRuleResult.new
      rr2 = BusinessValidationRuleResult.new

      rr1.state = 'Pass'
      rr2.state = 'Pass'
      
      bvr = described_class.new
      bvr.validatable = o

      [rr1,rr2].each do |x|
        bvr.business_validation_rule_results << x
        x.should_receive(:run_validation).with(o)
      end

      bvr.run_validation
      expect(bvr.state).to eq 'Pass'
    end
  end

  describe "failed?" do
    it "identfies failed state" do
      subject.state = "Fail"
      expect(subject).to be_failed
    end

    it "identifies non-failed state" do
      subject.state = "Literally anything else"
      expect(subject).not_to be_failed
    end
  end
end
