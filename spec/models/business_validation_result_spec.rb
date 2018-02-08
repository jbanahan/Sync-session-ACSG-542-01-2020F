require 'spec_helper'

describe BusinessValidationResult do
  describe "can_view" do
    it "should allow users who can view results" do
      u = Factory(:master_user)
      u.company.update_attributes(show_business_rules:true)
      expect(described_class.new.can_view?(u)).to eq true
    end
    it "should not allow who can't view results" do
      u = Factory(:user)
      expect(described_class.new.can_view?(u)).to eq false
    end
  end
  describe "can_edit" do
    it "should allow users from master company" do
      u = Factory(:master_user)
      u.company.update_attributes(show_business_rules:true)
      expect(described_class.new.can_edit?(u)).to eq true
    end
    it "should not allow users not from master company" do
      u = Factory(:user)
      expect(described_class.new.can_edit?(u)).to eq false
    end
  end
  describe "run_validation" do
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
        expect(x).to receive(:run_validation).with(o)
      end

      expect(bvr.run_validation).to eq true
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
        expect(x).to receive(:run_validation).with(o)
      end

      expect(bvr.run_validation).to eq true
      expect(bvr.state).to eq 'Pass'
    end
    it "should return false if the state doesn't change" do
      o = Order.new
      rr1 = BusinessValidationRuleResult.new

      rr1.state = 'Pass'

      bvr = described_class.new(state:'Pass')
      bvr.validatable = o

      [rr1].each do |x|
        bvr.business_validation_rule_results << x
        expect(x).to receive(:run_validation).with(o)
      end

      expect(bvr.run_validation).to eq false
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

  describe "run_validation_with_state_tracking" do
    let (:order) { Factory(:order, order_number: "ajklsdfajl") }
    let (:rule) { ValidationRuleFieldFormat.create! type:'ValidationRuleFieldFormat',rule_attributes_json:{model_field_uid:'ord_ord_num',regex:'12345'}.to_json}
    let (:rule_result) { 
      rr = BusinessValidationRuleResult.new
      rr.business_validation_rule = rule 
      rr.save!
      rr
    }
    let (:business_validation_result) { 
      r = BusinessValidationResult.create! validatable: order, state: "Failed"
      r.business_validation_rule_results << rule_result
      r
    }

    it "returns the states of all the rules" do
      expect(business_validation_result.run_validation_with_state_tracking).to eq({changed: true, rule_states: [{id: rule_result.id, changed: true, new_state: "Fail", old_state: nil}]})
    end
  end
end
