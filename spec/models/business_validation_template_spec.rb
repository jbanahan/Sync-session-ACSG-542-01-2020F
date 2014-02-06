require 'spec_helper'

describe BusinessValidationTemplate do
  describe :create_result! do
    it "should create result based on rules" do
      o = Order.new
      bvt = described_class.create!(module_type:'Order')
      rule = bvt.business_validation_rules.create!(type:'ValidationRuleFieldFormat')
      bvt.reload
      bvr = bvt.create_result! o
      expect(bvr.validatable).to eq o
      expect(bvr.business_validation_rule_results.count).to eq 1
      expect(bvr.business_validation_rule_results.first.business_validation_rule).to eq bvt.business_validation_rules.first
      expect(bvr.state).to be_nil #doesn't run validations
    end
    it "should return nil if object doeesn't pass search criterions" do
      o = Order.new(order_number:'DontMatch')
      bvt = described_class.create!(module_type:'Order')
      bvt.search_criterions.create!(model_field_uid:'ord_ord_num',operator:'eq',value:'xx')
      rule = bvt.business_validation_rules.create!(type:'ValidationRuleFieldFormat')
      bvt.reload
      bvr = bvt.create_result! o
      expect(bvr).to be_nil
      expect(BusinessValidationResult.count).to eq 0
    end
  end
end
