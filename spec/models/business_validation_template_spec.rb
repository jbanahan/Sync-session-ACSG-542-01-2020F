require 'spec_helper'

describe BusinessValidationTemplate do
  describe "create_all!" do
    before :each do
      allow(OpenChain::StatClient).to receive(:wall_time).and_yield
    end
    it "should run all templates" do
      Factory(:business_validation_template)
      expect_any_instance_of(BusinessValidationTemplate).to receive(:create_results!).with(run_validation: true)
      BusinessValidationTemplate.create_all! run_validation: true
    end
  end
  describe "create_results!" do
    before :each do
      @bvt = Factory(:business_validation_template)
      @bvt.search_criterions.create!(model_field_uid:'ent_cust_num',operator:'eq',value:'12345')
      @bvt.business_validation_rules.create!(type:'ValidationRuleFieldFormat',rule_attributes_json:{model_field_uid:'ent_entry_num',regex:'X'}.to_json)
      @bvt.reload
    end
    it "should create results for entries that match search criterions and don't have business_validation_result" do
      match = Factory(:entry,customer_number:'12345')
      # don't match
      Factory(:entry,customer_number:'54321')
      @bvt.create_results!
      expect(BusinessValidationResult.scoped.count).to eq 1
      expect(BusinessValidationResult.first.validatable).to eq match
      expect(BusinessValidationResult.first.state).to be_nil
    end
    it "should run validation if flag set" do
      Factory(:entry,customer_number:'12345')
      expect{@bvt.create_results! run_validation: true}.to change(BusinessValidationResult,:count).from(0).to(1)
      expect(BusinessValidationResult.first.state).not_to be_nil
    end
    it "should update results for entries that match search criterions and have old business_validation_result" do
      match = Factory(:entry,customer_number:'12345')
      @bvt.create_results! run_validation: true
      bvr = BusinessValidationResult.first
      expect(bvr.validatable).to eq match
      expect(bvr.state).to eq 'Fail'
      match.update_attributes(entry_number:'X')
      bvr.update_attributes(updated_at:10.seconds.ago)
      @bvt.create_results! run_validation: true
      bvr.reload
      expect(bvr.state).to eq 'Pass'
    end
    it "should only call once per entry" do
      match = Factory(:entry,customer_number:'12345')
      Factory(:commercial_invoice,entry:match)
      Factory(:commercial_invoice,entry:match)
      @bvt.create_results! run_validation: true
      expect(BusinessValidationResult.count).to eq 1
    end
    it 'rescues exceptions raise in create_result! call' do
      match = Factory(:entry,customer_number:'12345')
      expect(@bvt).to receive(:create_result!).and_raise "Error"
      @bvt.create_results!
      expect(ErrorLogEntry.last.additional_messages).to eq ["Failed to generate rule results for Entry id #{match.id}"]
    end
    it "limits query results to only those associated w/ the current template" do
      # This makes sure we're not getting results back from other templates that have outdated rule results...bug resolution
      entry = Factory(:entry,customer_number:'12345')
      @bvt.business_validation_results.create! validatable: entry, state: "Pass", updated_at: (entry.updated_at - 1.hour)

      template = Factory(:business_validation_template)
      template.search_criterions.create!(model_field_uid:'ent_cust_num',operator:'eq',value:'12345')
      template.business_validation_rules.create!(type:'ValidationRuleFieldFormat',rule_attributes_json:{model_field_uid:'ent_entry_num',regex:'12345'}.to_json)
      template.business_validation_results.create! validatable: entry, state: "Pass", updated_at: (entry.updated_at + 1.hour)
      template.reload

      expect(template).not_to receive(:create_result!)

      template.create_results!
    end
    it "does not evaulate anything if there are no criterions associated with the template" do
      @bvt.search_criterions.destroy_all

      @bvt.create_results!
      expect(BusinessValidationResult.count).to eq 0
    end
  end
  describe "create_result!" do
    before :each do
      @o = Factory(:order, order_number: "ajklsdfajl")
      @bvt = described_class.create!(module_type:'Order')
      @bvt.business_validation_rules.create!(type:'ValidationRuleFieldFormat')
      @bvt.search_criterions.create! model_field_uid: "ord_ord_num", operator: "nq", value: "XXXXXXXXXX"
      @bvt.reload
      allow_any_instance_of(Order).to receive(:create_snapshot)
    end

    it "should create result based on rules" do
      bvr = @bvt.create_result! @o
      bvr.reload
      expect(bvr.validatable).to eq @o
      expect(bvr.business_validation_rule_results.count).to eq 1
      expect(bvr.business_validation_rule_results.first.business_validation_rule).to eq @bvt.business_validation_rules.first
      expect(bvr.state).to be_nil #doesn't run validations
    end
    it "should return nil if object doeesn't pass search criterions" do
      @o.update_attribute(:order_number, 'DontMatch')
      @bvt.search_criterions.create!(model_field_uid:'ord_ord_num',operator:'eq',value:'xx')
      bvr = @bvt.create_result! @o
      expect(bvr).to be_nil
      expect(BusinessValidationResult.count).to eq 0
    end
    it "should not duplicate rules that already exist" do
      @bvt.create_result! @o
      @bvt.create_result! @o
      expect(BusinessValidationResult.count).to eq 1
      expect(BusinessValidationRuleResult.count).to eq 1
    end
    it "doesn't create rule results if the rule has delete_pending" do
      @bvt.business_validation_rules.first.update_attribute(:delete_pending, true)
      @bvt.create_result! @o
      expect(BusinessValidationRuleResult.count).to eq 0
    end
    it "should run validation if attribute passed" do
      expect(Lock).to receive(:with_lock_retry).ordered.with(an_instance_of(Order)).and_yield
      expect(Lock).to receive(:with_lock_retry).ordered.with(an_instance_of(BusinessValidationResult)).and_yield
      
      expect_any_instance_of(Order).to receive(:create_snapshot).with(User.integration,nil,"Business Rule Update")
      @bvt.business_validation_rules.first.update_attribute(:rule_attributes_json, {model_field_uid:'ord_ord_num',regex:'X'}.to_json)
      bvr = @bvt.create_result! @o, run_validation: true
      expect(bvr.validatable).to eq @o
      expect(bvr.state).not_to be_nil
    end
    it "utilizes database locking while creating and validating objects" do
      expect(Lock).to receive(:with_lock_retry).ordered.with(an_instance_of(Order)).and_yield
      expect(Lock).to receive(:with_lock_retry).with(instance_of(BusinessValidationResult)).and_yield

      @bvt.create_result! @o
    end

    it "does not create results if the template has no search_criterions" do
      @bvt.search_criterions.destroy_all

      expect(@bvt.create_result! @o).to be_nil
      expect(BusinessValidationResult.first).to be_nil
    end

    it "removes stale result records if the template no longer is applicable to the object under test" do
      # Add a search criterion that eliminates the order from the template rules
      @bvt.search_criterions.create! model_field_uid: "ord_ord_num", operator: "eq", value: "1234567890"
      @o.business_validation_results.create! business_validation_template_id: @bvt.id, state: "Fail"

      @bvt.create_result! @o
      @o.reload
      expect(@o.business_validation_results.length).to eq 0
    end

    it "does not snapshot the entity if instructed not to" do
      @o = Factory(:order, order_number: "ajklsdfajl")
      @bvt = described_class.create!(module_type:'Order')
      @bvt.business_validation_rules.create!(type:'ValidationRuleFieldFormat')
      @bvt.search_criterions.create! model_field_uid: "ord_ord_num", operator: "nq", value: "XXXXXXXXXX"
      @bvt.reload

      expect_any_instance_of(Order).not_to receive(:create_snapshot)
      @bvt.create_result! @o
    end
  end

  describe "create_results_for_object!" do
    it "should create results" do
      expect(BusinessValidationTemplate.count).to eq 0
      bvt1 = described_class.create!(module_type:'Order')
      bvt1.search_criterions.create! model_field_uid: "ord_ord_num", operator: "nq", value: "XXXXXXXXXX"
      bvt2 = described_class.create!(module_type:'Order')
      bvt2.search_criterions.create! model_field_uid: "ord_ord_num", operator: "nq", value: "XXXXXXXXXX"
      bvt_ignore = described_class.create!(module_type:'Entry')

      ord = Factory(:order, order_number: "ABCD")
      expect{described_class.create_results_for_object!(ord)}.to change(BusinessValidationResult,:count).from(0).to(2)
      [bvt1,bvt2].each do |b|
        b.reload
        expect(b.business_validation_results.first.validatable).to eq ord
      end

      expect(ord.entity_snapshots.length).to eq 2
    end

    it "does not snapshot the entity if flag is utilized" do
      bvt1 = described_class.create!(module_type:'Order')
      bvt1.search_criterions.create! model_field_uid: "ord_ord_num", operator: "nq", value: "XXXXXXXXXX"
      bvt2 = described_class.create!(module_type:'Order')
      bvt2.search_criterions.create! model_field_uid: "ord_ord_num", operator: "nq", value: "XXXXXXXXXX"
      bvt_ignore = described_class.create!(module_type:'Entry')

      ord = Factory(:order, order_number: "ABCD")

      expect_any_instance_of(Order).not_to receive(:create_snapshot)
      described_class.create_results_for_object!(ord, snapshot_entity: false)
    end
  end
  describe "run_schedulable" do
    it "implements schedulable job interface" do
      expect(BusinessValidationTemplate).to receive(:create_all!).with(run_validation: true)
      BusinessValidationTemplate.run_schedulable
    end

    it "allows setting run_validation param via opts to false" do
      expect(BusinessValidationTemplate).to receive(:create_all!).with(run_validation: false)
      BusinessValidationTemplate.run_schedulable 'run_validation' => false
    end
  end
  describe "async_destroy" do
    it "destroys record" do
      template = Factory(:business_validation_template)
      described_class.async_destroy template.id
      expect(described_class.count).to eq 0
    end
  end
end
