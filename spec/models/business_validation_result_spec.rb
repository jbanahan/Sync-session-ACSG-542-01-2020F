describe BusinessValidationResult do
  let(:bvr) { FactoryBot(:business_validation_result) }

  describe "can_view" do
    it "allows users who can view results" do
      u = FactoryBot(:master_user)
      u.company.update(show_business_rules: true)
      expect(bvr.can_view?(u)).to eq true
    end

    it "does not allow who can't view results" do
      u = FactoryBot(:user)
      expect(bvr.can_view?(u)).to eq false
    end

    context "private results" do
      before do
        bvr.business_validation_template.update! private: true
      end

      it "allows users with viewing rights" do
        u = FactoryBot(:master_user)
        u.company.update(show_business_rules: true)
        expect(bvr.can_view?(u)).to eq true
      end

      it "blocks users without viewing rights" do
        u = FactoryBot(:user)
        u.company.update(show_business_rules: true)
        expect(bvr.can_view?(u)).to eq false
      end
    end
  end

  describe "can_edit" do
    it "allows users from master company" do
      u = FactoryBot(:master_user)
      u.company.update(show_business_rules: true)
      expect(bvr.can_edit?(u)).to eq true
    end

    it "does not allow users not from master company" do
      u = FactoryBot(:user)
      expect(bvr.can_edit?(u)).to eq false
    end
  end

  describe "run_validation" do
    it "sets state to worst of rule results" do
      o = Order.new
      rr1 = BusinessValidationRuleResult.new
      rr2 = BusinessValidationRuleResult.new
      rr3 = BusinessValidationRuleResult.new
      rr4 = BusinessValidationRuleResult.new

      rr1.state = 'Pass'
      rr2.state = 'Fail'
      rr3.state = 'Review'
      rr4.state = 'Skipped'

      bvr.validatable = o

      [rr1, rr2, rr3, rr4].each do |x|
        bvr.business_validation_rule_results << x
        expect(x).to receive(:run_validation).with(o)
      end

      expect(bvr.run_validation).to eq true
      expect(bvr.state).to eq 'Fail'
    end

    it "passes if all rules pass" do
      o = Order.new
      rr1 = BusinessValidationRuleResult.new
      rr2 = BusinessValidationRuleResult.new

      rr1.state = 'Pass'
      rr2.state = 'Pass'

      bvr.validatable = o

      [rr1, rr2].each do |x|
        bvr.business_validation_rule_results << x
        expect(x).to receive(:run_validation).with(o)
      end

      expect(bvr.run_validation).to eq true
      expect(bvr.state).to eq 'Pass'
    end

    it "returns false if the state doesn't change" do
      o = Order.new
      rr1 = BusinessValidationRuleResult.new

      rr1.state = 'Pass'

      bvr.update! state: 'Pass'
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
    let(:order) { FactoryBot(:order, order_number: "ajklsdfajl") }
    let(:rule) do
      ValidationRuleFieldFormat.create! type: 'ValidationRuleFieldFormat', name: "Name", description: "Description",
                                        rule_attributes_json: {model_field_uid: 'ord_ord_num', regex: '12345'}.to_json
    end

    let(:rule_result) do
      rr = BusinessValidationRuleResult.new
      rr.business_validation_rule = rule
      rr.save!
      rr
    end

    let(:business_validation_result) do
      r = described_class.create! validatable: order, state: "Failed"
      r.business_validation_rule_results << rule_result
      r
    end

    it "returns the states of all the rules" do
      expect(rule).to receive(:active?).and_return true
      expect(business_validation_result.run_validation_with_state_tracking)
        .to eq({changed: true, rule_states: [{id: rule_result.id, changed: true, new_state: "Fail", old_state: nil}]})
    end
  end

  context "state checks" do
    ["Fail", "Review", "Pass", "Skipped"].each do |state|
      it "validates #{state.downcase}?" do
        method_name = state == "Fail" ? "failed" : state.downcase
        expect(described_class.new(state: state).send("#{method_name}?".to_sym)).to eq true
        expect(described_class.new(state: "something else").send("#{method_name}?".to_sym)).to eq false
      end

      it "validates #{state.downcase}_state?" do
        expect(described_class.send("#{state.downcase}_state?".to_sym, state)).to eq true
        expect(described_class.send("#{state.downcase}_state?".to_sym, "something else")).to eq false
      end
    end
  end
end
