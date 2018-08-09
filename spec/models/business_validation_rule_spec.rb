require 'spec_helper'

describe BusinessValidationRule do
  describe "enabled?" do
    it "should not return !enabled in subclasses_array" do
      expect(described_class.subclasses_array.find {|a| a[1]=='PoloValidationRuleEntryInvoiceLineMatchesPoLine'}).to be_nil
    end
    it "should return when no enabled lambda in subclasses_array" do
      a = described_class.subclasses_array
      expect(a.find {|a| a[1]=='ValidationRuleManual'}).to_not be_nil
    end
  end

  describe "should_skip?" do
    it "should base should_skip? on search_criterions" do
      pass_ent = Entry.new(entry_number:'9')
      fail_ent = Entry.new(entry_number:'7')
      bvr = BusinessValidationRule.new
      bvr.search_criterions.build(model_field_uid:'ent_entry_num',operator:'eq',value:'9')
      expect(bvr.should_skip?(pass_ent)).to be_falsey
      expect(bvr.should_skip?(fail_ent)).to be_truthy
    end
    it "should raise exception if search_criterion's model field CoreModule doesn't equal object's CoreModule" do
      bvr = BusinessValidationRule.new
      bvr.search_criterions.build(model_field_uid:'ent_entry_num',operator:'eq',value:'9')
      ci = CommercialInvoiceLine.new
      expect {bvr.should_skip? ci}.to raise_error /Invalid object expected Entry got CommercialInvoiceLine/
    end
  end

  describe "destroy" do
    it "destroys record" do
      rule = Factory(:business_validation_rule)
      rule.destroy
      expect(described_class.count).to eq 0
    end

    context "validate result deletes", :disable_delayed_jobs do

      it "destroys validation rule and dependents" do
        rule_result = Factory(:business_validation_rule_result)
        rule = rule_result.business_validation_rule

        rule.destroy

        expect(BusinessValidationRuleResult.where(id: rule_result).first).to be_nil
      end
    end
  end

  describe "has_flag?" do
    [true, "1", "true"].each do |v|
      it "returns true of attribute flag value is set with boolean true value #{v}" do
        subject.rule_attributes_json = {value: v}.to_json
        expect(subject.has_flag? "value").to eq true
      end
    end

    [false, "0", "false", nil].each do |v|
      it "returns false of attribute flag value is set with boolean false value #{v}" do
        subject.rule_attributes_json = {value: v}.to_json
        expect(subject.has_flag? "value").to eq false
      end
    end

    it "returns false if flag is not set" do
      expect(subject.has_flag? "value").to eq false
    end
    
  end

  describe "active?" do
    let(:bvt) { Factory(:business_validation_template)}
    let(:bvru) { Factory(:business_validation_rule, business_validation_template: bvt, disabled: false, delete_pending: false)}
    before { allow(bvt).to receive(:active?).and_return true }
  
    it "returns false if disabled" do
      bvru.update_attributes! disabled: true
      expect(bvru.active?).to eq false
    end

    it "returns false if delete_pending" do
      bvru.update_attributes! delete_pending: true
      expect(bvru.active?).to eq false
    end

    it "returns false if template isn't active" do
      allow(bvt).to receive(:active?).and_return false
      expect(bvru.active?).to eq false
    end
    
    it "returns true otherwise" do
      expect(bvru.active?).to eq true
    end
  end

end
