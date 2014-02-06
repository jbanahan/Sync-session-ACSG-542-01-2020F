require 'spec_helper'

describe BusinessValidationResult do
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
end
