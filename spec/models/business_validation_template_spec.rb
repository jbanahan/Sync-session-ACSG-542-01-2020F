require 'spec_helper'

describe BusinessValidationTemplate do
  describe :create_all! do
    before :each do
      OpenChain::StatClient.stub(:wall_time).and_yield
    end
    it "should run all templates" do
      Factory(:business_validation_template)
      BusinessValidationTemplate.any_instance.should_receive(:create_results!).with(boolean())
      BusinessValidationTemplate.create_all! true
    end
  end
  describe :create_results! do
    before :each do
      @bvt = Factory(:business_validation_template)
      @bvt.search_criterions.create!(model_field_uid:'ent_cust_num',operator:'eq',value:'12345')
      @bvt.business_validation_rules.create!(type:'ValidationRuleFieldFormat',rule_attributes_json:{model_field_uid:'ent_entry_num',regex:'X'}.to_json)
      @bvt.reload
    end
    it "should create results for entries that match search criterions and don't have business_validation_result" do
      match = Factory(:entry,customer_number:'12345')
      dont_match = Factory(:entry,customer_number:'54321')
      @bvt.create_results!
      expect(BusinessValidationResult.scoped.count).to eq 1
      expect(BusinessValidationResult.first.validatable).to eq match
      expect(BusinessValidationResult.first.state).to be_nil
    end
    it "should run validation if flag set" do
      match = Factory(:entry,customer_number:'12345')
      @bvt.create_results! true
      expect(BusinessValidationResult.first.state).not_to be_nil
    end
    it "should update results for entries that match search criterions and have old business_validation_result" do
      match = Factory(:entry,customer_number:'12345')
      @bvt.create_results! true
      bvr = BusinessValidationResult.first
      expect(bvr.validatable).to eq match
      expect(bvr.state).to eq 'Fail'
      match.update_attributes(entry_number:'X')
      bvr.update_attributes(updated_at:10.seconds.ago)
      @bvt.create_results! true
      bvr.reload
      expect(bvr.state).to eq 'Pass'
    end
    it "should only call once per entry" do
      match = Factory(:entry,customer_number:'12345')
      Factory(:commercial_invoice,entry:match)
      Factory(:commercial_invoice,entry:match)
      @bvt.create_results! true
      expect(BusinessValidationResult.count).to eq 1
    end
    it 'rescues exceptions raise in create_result! call' do
      match = Factory(:entry,customer_number:'12345')
      @bvt.should_receive(:create_result!).and_raise "Error"
      StandardError.any_instance.should_receive(:log_me).with ["Failed to generate rule results for Entry id #{match.id}"]
      @bvt.create_results!
    end
  end
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
    it "should not duplicate rules that already exist" do
      o = Order.new
      bvt = described_class.create!(module_type:'Order')
      rule = bvt.business_validation_rules.create!(type:'ValidationRuleFieldFormat')
      bvt.reload
      bvt.create_result! o
      bvt.create_result! o
      expect(BusinessValidationResult.count).to eq 1
      expect(BusinessValidationRuleResult.count).to eq 1
    end
    it "should run validation if attribute passed" do
      o = Order.new
      bvt = described_class.create!(module_type:'Order')
      rule = bvt.business_validation_rules.create!(type:'ValidationRuleFieldFormat',rule_attributes_json:{model_field_uid:'ord_ord_num',regex:'X'}.to_json)
      bvt.reload
      bvr = bvt.create_result! o, true
      expect(bvr.validatable).to eq o
      expect(bvr.state).not_to be_nil
    end
    it "utilizes database locking while creating and validating objects" do
      o = Order.new
      bvt = described_class.create!(module_type:'Order')
      rule = bvt.business_validation_rules.create!(type:'ValidationRuleFieldFormat')
      bvt.reload

      Lock.should_receive(:with_lock_retry).with(bvt).and_yield
      Lock.should_receive(:with_lock_retry).with(instance_of(BusinessValidationResult)).and_yield

      bvt.create_result! o
    end
  end
end
