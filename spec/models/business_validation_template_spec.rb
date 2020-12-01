describe BusinessValidationTemplate do
  describe "create_all!" do
    before do
      allow(OpenChain::StatClient).to receive(:wall_time).and_yield
    end

    it "runs all templates" do
      FactoryBot(:business_validation_template)
      expect_any_instance_of(described_class).to receive(:create_results!).with(run_validation: true)
      described_class.create_all! run_validation: true
    end

    it "skips disabled templates" do
      FactoryBot(:business_validation_template, disabled: true)
      expect_any_instance_of(described_class).not_to receive(:create_results!)
      described_class.create_all!
    end

    it "skips delete_pending templates" do
      FactoryBot(:business_validation_template, delete_pending: true)
      expect_any_instance_of(described_class).not_to receive(:create_results!)
      described_class.create_all!
    end
  end

  describe "create_results!" do
    let(:business_validation_template) do
      bvt = FactoryBot(:business_validation_template)
      bvt.search_criterions.create!(model_field_uid: 'ent_cust_num', operator: 'eq', value: '12345')
      bvt.business_validation_rules.create!(name: "Name", description: "Description", type: 'ValidationRuleFieldFormat',
                                            rule_attributes_json: {model_field_uid: 'ent_entry_num', regex: 'X'}.to_json)
      bvt
    end

    it "creates results for entries that match search criterions and don't have business_validation_result" do
      match = FactoryBot(:entry, customer_number: '12345')
      # don't match
      FactoryBot(:entry, customer_number: '54321')
      business_validation_template.create_results!
      expect(BusinessValidationResult.all.count).to eq 1
      expect(BusinessValidationResult.first.validatable).to eq match
      expect(BusinessValidationResult.first.state).to be_nil
    end

    it "runs validation if flag set" do
      FactoryBot(:entry, customer_number: '12345')
      expect {business_validation_template.create_results! run_validation: true}.to change(BusinessValidationResult, :count).from(0).to(1)
      expect(BusinessValidationResult.first.state).not_to be_nil
    end

    it "updates results for entries that match search criterions and have old business_validation_result" do
      match = FactoryBot(:entry, customer_number: '12345')
      expect(BusinessRuleSnapshot).to receive(:create_from_entity).with(match).twice
      business_validation_template.create_results! run_validation: true
      bvr = BusinessValidationResult.first
      expect(bvr.validatable).to eq match
      expect(bvr.state).to eq 'Fail'
      match.update(entry_number: 'X')
      bvr.update(updated_at: 10.seconds.ago)
      business_validation_template.create_results! run_validation: true
      bvr.reload
      expect(bvr.state).to eq 'Pass'

      # There should be 2 snapshots (1 for the first create_results call, one for the second)
      expect(match.entity_snapshots.length).to eq 2
      s = match.entity_snapshots.first
      expect(s.user).to eq User.integration
      expect(s.context).to eq "Business Rule Update"
    end

    it "only calls once per entry" do
      match = FactoryBot(:entry, customer_number: '12345')
      FactoryBot(:commercial_invoice, entry: match)
      FactoryBot(:commercial_invoice, entry: match)
      business_validation_template.create_results! run_validation: true
      expect(BusinessValidationResult.count).to eq 1
    end

    it 'rescues exceptions raise in create_result! call' do
      match = FactoryBot(:entry, customer_number: '12345')
      expect(business_validation_template).to receive(:create_result!).and_raise "Error"
      business_validation_template.create_results!
      expect(ErrorLogEntry.last.additional_messages).to eq ["Failed to generate rule results for Entry id #{match.id}"]
    end

    it "limits query results to only those associated w/ the current template" do
      # This makes sure we're not getting results back from other templates that have outdated rule results...bug resolution
      entry = FactoryBot(:entry, customer_number: '12345')
      business_validation_template.business_validation_results.create! validatable: entry, state: "Pass", updated_at: (entry.updated_at - 1.hour)

      template = FactoryBot(:business_validation_template)
      template.search_criterions.create!(model_field_uid: 'ent_cust_num', operator: 'eq', value: '12345')
      template.business_validation_rules.create!(name: "Name", description: "Description", type: 'ValidationRuleFieldFormat',
                                                 rule_attributes_json: {model_field_uid: 'ent_entry_num', regex: '12345'}.to_json)
      template.business_validation_results.create! validatable: entry, state: "Pass", updated_at: (entry.updated_at + 1.hour)
      template.reload

      expect(template).not_to receive(:create_result!)

      template.create_results!
    end

    it "does not evaulate anything if there are no criterions associated with the template" do
      expect(Entry).not_to receive(:select)
      business_validation_template.search_criterions.destroy_all
      FactoryBot(:entry, customer_number: '12345')
      business_validation_template.create_results! run_validation: true
      expect(BusinessValidationResult.count).to eq 0
    end

    it "does not evaluate anything if template is disabled" do
      expect(Entry).not_to receive(:select)
      FactoryBot(:entry, customer_number: '12345')
      business_validation_template.update! disabled: true
      business_validation_template.create_results! run_validation: true
      expect(BusinessValidationResult.count).to eq 0
    end

    it "does not evaluate anything if template is delete_pending" do
      expect(Entry).not_to receive(:select)
      FactoryBot(:entry, customer_number: '12345')
      business_validation_template.update! delete_pending: true
      business_validation_template.create_results! run_validation: true
      expect(BusinessValidationResult.count).to eq 0
    end

    it "does not re-snapshot objects where the rule state doesn't change" do
      match = FactoryBot(:entry, customer_number: '12345')
      expect(BusinessRuleSnapshot).to receive(:create_from_entity).with(match).once
      business_validation_template.create_results! run_validation: true
      bvr = BusinessValidationResult.first
      expect(bvr.validatable).to eq match
      expect(bvr.state).to eq 'Fail'
      bvr.update(updated_at: 10.seconds.ago)
      business_validation_template.create_results! run_validation: true
      bvr.reload
      expect(bvr.state).to eq 'Fail'

      # There should be 1 snapshot because the result didn't change and no rule states changed internally
      expect(match.entity_snapshots.length).to eq 1
    end
  end

  describe "create_result!" do
    let(:order) { FactoryBot(:order, order_number: "ajklsdfajl") }

    let(:business_validation_template) do
      bvt = described_class.create!(module_type: 'Order')
      bvt.business_validation_rules.create!(name: "Name", description: "Description", type: 'ValidationRuleFieldFormat')
      bvt.search_criterions.create! model_field_uid: "ord_ord_num", operator: "nq", value: "XXXXXXXXXX"
      bvt.reload
      bvt
    end

    before do
      allow_any_instance_of(Order).to receive(:create_snapshot)
    end

    it "returns nil if not active" do
      expect(business_validation_template).to receive(:active?).and_return false
      expect(business_validation_template.create_result!(order)).to be_nil
    end

    it "creates result based on rules" do
      result = business_validation_template.create_result! order
      bvr = result[:result]

      bvr.reload
      expect(bvr.validatable).to eq order
      expect(bvr.business_validation_rule_results.count).to eq 1
      expect(bvr.business_validation_rule_results.first.business_validation_rule).to eq business_validation_template.business_validation_rules.first
      expect(bvr.state).to be_nil # doesn't run validations
    end

    it "returns nil if object doeesn't pass search criterions" do
      order.update(order_number: 'DontMatch')
      business_validation_template.search_criterions.create!(model_field_uid: 'ord_ord_num', operator: 'eq', value: 'xx')
      result = business_validation_template.create_result! order
      expect(result).to be_nil
      expect(BusinessValidationResult.count).to eq 0
    end

    it "does not duplicate rules that already exist" do
      business_validation_template.create_result! order
      business_validation_template.create_result! order
      expect(BusinessValidationResult.count).to eq 1
      expect(BusinessValidationRuleResult.count).to eq 1
    end

    it "doesn't create rule results if the rule isn't active" do
      bvru = business_validation_template.business_validation_rules.first
      expect_any_instance_of(BusinessValidationRule).to receive(:active?) do |rule|
        expect(rule.id).to eq bvru.id
        false
      end
      business_validation_template.create_result! order
      expect(BusinessValidationRuleResult.count).to eq 0
    end

    it "runs validation if attribute passed" do
      expect(Lock).to receive(:with_lock_retry).ordered.with(an_instance_of(Order)).and_yield
      expect(Lock).to receive(:with_lock_retry).ordered.with(an_instance_of(BusinessValidationResult)).and_yield

      business_validation_template.business_validation_rules.first.update(rule_attributes_json: {model_field_uid: 'ord_ord_num', regex: 'X'}.to_json)
      result = business_validation_template.create_result! order, run_validation: true
      bvr = result[:result]
      expect(bvr.validatable).to eq order
      expect(bvr.state).not_to be_nil
    end

    it "utilizes database locking while creating and validating objects" do
      expect(Lock).to receive(:with_lock_retry).ordered.with(an_instance_of(Order)).and_yield
      expect(Lock).to receive(:with_lock_retry).with(instance_of(BusinessValidationResult)).and_yield

      business_validation_template.create_result! order
    end

    it "does not create results if the template has no search_criterions" do
      business_validation_template.search_criterions.destroy_all

      expect(business_validation_template.create_result!(order)).to be_nil
      expect(BusinessValidationResult.first).to be_nil
    end

    it "removes stale result records if the template no longer is applicable to the object under test" do
      # Add a search criterion that eliminates the order from the template rules
      business_validation_template.search_criterions.create! model_field_uid: "ord_ord_num", operator: "eq", value: "1234567890"
      order.business_validation_results.create! business_validation_template_id: business_validation_template.id, state: "Fail"

      business_validation_template.create_result! order
      order.reload
      expect(order.business_validation_results.length).to eq 0
    end

    it "does not snapshot the entity if instructed not to" do
      order = FactoryBot(:order, order_number: "ajklsdfajl")
      business_validation_template = described_class.create!(module_type: 'Order')
      business_validation_template.business_validation_rules.create!(name: "Name", description: "Description", type: 'ValidationRuleFieldFormat')
      business_validation_template.search_criterions.create! model_field_uid: "ord_ord_num", operator: "nq", value: "XXXXXXXXXX"
      business_validation_template.reload

      expect_any_instance_of(Order).not_to receive(:create_snapshot)
      business_validation_template.create_result! order
    end

    it "does not run validations on closed object if instructed not to" do
      ms = stub_master_setup
      expect(ms).to receive(:custom_feature?).with("Disable Rules For Closed Objects").and_return true
      expect(order).to receive(:closed?).and_return true

      result = business_validation_template.create_result! order, run_validation: true

      expect(result[:result]).not_to be_nil
      expect(result[:tracking]).to be_nil
    end

    it "runs validations on closed object if not disabled" do
      ms = stub_master_setup
      expect(ms).to receive(:custom_feature?).with("Disable Rules For Closed Objects").and_return false
      expect(order).to receive(:closed?).and_return true

      result = business_validation_template.create_result! order, run_validation: true

      expect(result[:result]).not_to be_nil
      expect(result[:tracking]).not_to be_nil
    end
  end

  describe "create_results_for_object!" do
    it "creates results" do
      expect(described_class.count).to eq 0
      bvt1 = described_class.create!(module_type: 'Order')
      bvt1.search_criterions.create! model_field_uid: "ord_ord_num", operator: "nq", value: "XXXXXXXXXX"
      bvt2 = described_class.create!(module_type: 'Order')
      bvt2.search_criterions.create! model_field_uid: "ord_ord_num", operator: "nq", value: "XXXXXXXXXX"
      described_class.create!(module_type: 'Entry')

      ord = FactoryBot(:order, order_number: "ABCD")
      expect(BusinessRuleSnapshot).to receive(:create_from_entity).with(ord)
      expect {described_class.create_results_for_object!(ord)}.to change(BusinessValidationResult, :count).from(0).to(2)
      [bvt1, bvt2].each do |b|
        b.reload
        expect(b.business_validation_results.first.validatable).to eq ord
      end

      # Only a single snapshot should be generated, even though 2 templates are evaluated
      expect(ord.entity_snapshots.length).to eq 1
    end

    it "does not snapshot the entity if flag is utilized" do
      bvt1 = described_class.create!(module_type: 'Order')
      bvt1.search_criterions.create! model_field_uid: "ord_ord_num", operator: "nq", value: "XXXXXXXXXX"
      bvt2 = described_class.create!(module_type: 'Order')
      bvt2.search_criterions.create! model_field_uid: "ord_ord_num", operator: "nq", value: "XXXXXXXXXX"
      described_class.create!(module_type: 'Entry')

      ord = FactoryBot(:order, order_number: "ABCD")

      expect_any_instance_of(Order).not_to receive(:create_snapshot)
      described_class.create_results_for_object!(ord, snapshot_entity: false)
    end

    it "does not snapshot if the overall rule state stays the same and no rule states change" do
      ord = FactoryBot(:order, order_number: "ABCD")
      bvt = described_class.create!(module_type: 'Order')
      bvt.search_criterions.create! model_field_uid: "ord_ord_num", operator: "nq", value: "XXXXXXXXXX"
      bvt.business_validation_rules.create! name: "Name", description: "Description", type: 'ValidationRuleFieldFormat',
                                            rule_attributes_json: {model_field_uid: 'ord_ord_num', regex: '12345'}.to_json
      bvt.business_validation_rules.create! name: "Name", description: "Description", type: 'ValidationRuleFieldFormat',
                                            rule_attributes_json: {model_field_uid: 'ord_ord_num', regex: '12345'}.to_json
      expect(BusinessRuleSnapshot).to receive(:create_from_entity).with(ord).once

      tz = ActiveSupport::TimeZone["America/New_York"]

      first_time = tz.parse("2018-01-01 00:00")
      Timecop.freeze(first_time) do
        described_class.create_results_for_object!(ord)
      end

      ord.reload
      expect(ord.entity_snapshots.length).to eq 1

      second_time = tz.parse("2018-02-01 00:00")
      Timecop.freeze(second_time) do
        described_class.create_results_for_object!(ord)
      end

      ord.reload
      expect(ord.entity_snapshots.length).to eq 1

      # The rule result's updated at should have been updated even though no rule states changed at all
      expect(ord.business_validation_results.first.updated_at).to eq second_time
    end

    it "snapshots if the overall rule state stays the same but rule status changes" do
      ord = FactoryBot(:order, order_number: "ABCD")
      bvt = described_class.create!(module_type: 'Order')
      bvt.search_criterions.create! model_field_uid: "ord_ord_num", operator: "nq", value: "XXXXXXXXXX"
      bvt.business_validation_rules.create! name: "Name", description: "Description", type: 'ValidationRuleFieldFormat',
                                            rule_attributes_json: {model_field_uid: 'ord_ord_num', regex: '12345'}.to_json
      rule2 = bvt.business_validation_rules.create! name: "Name", description: "Description", type: 'ValidationRuleFieldFormat',
                                                    rule_attributes_json: {model_field_uid: 'ord_ord_num', regex: '12345'}.to_json
      expect(BusinessRuleSnapshot).to receive(:create_from_entity).with(ord).twice

      described_class.create_results_for_object!(ord)

      # Update rule2 so that it passes, which should result in a rule status change, but the overall rule state staying the same
      rule2.update! rule_attributes_json: {model_field_uid: 'ord_ord_num', regex: 'ABCD'}.to_json

      described_class.create_results_for_object!(ord)
      ord.reload

      expect(ord.entity_snapshots.length).to eq 2
    end
  end

  describe "run_schedulable" do
    it "implements schedulable job interface" do
      expect(described_class).to receive(:create_all!).with(run_validation: true)
      described_class.run_schedulable
    end

    it "allows setting run_validation param via opts to false" do
      expect(described_class).to receive(:create_all!).with(run_validation: false)
      described_class.run_schedulable 'run_validation' => false
    end
  end

  describe "async_destroy" do
    it "destroys record" do
      template = FactoryBot(:business_validation_template)
      described_class.async_destroy template.id
      expect(described_class.count).to eq 0
    end
  end

  describe "create_results_for_object_ids!" do
    subject {described_class }

    let (:object) { FactoryBot(:product) }

    it "looks up the object and passes it to create_results_for_object" do
      expect(subject).to receive(:create_results_for_object!).with(object, snapshot_entity: true)
      subject.create_results_for_object_ids! "Product", [object.id]
    end

    it "handles actual class being passed as the object_type" do
      expect(subject).to receive(:create_results_for_object!).with(object, snapshot_entity: true)
      subject.create_results_for_object_ids! Product, [object.id]
    end

    it "handles missing objects" do
      expect(subject).not_to receive(:create_results_for_object!)
      subject.create_results_for_object_ids! Product, [-1]
    end

    it "allows for passing single id, not as an array" do
      expect(subject).to receive(:create_results_for_object!).with(object, snapshot_entity: true)
      subject.create_results_for_object_ids! "Product", object.id
    end
  end

  describe "active?" do
   subject { FactoryBot(:business_validation_template, disabled: false, delete_pending: false, search_criterions: [FactoryBot(:search_criterion)]) }

   it "returns false if disabled" do
     subject.update! disabled: true
     expect(subject.active?).to eq false
   end

   it "returns false if delete_pending" do
     subject.update! delete_pending: true
     expect(subject.active?).to eq false
   end

   it "returns false if there are no search criterions" do
     subject.search_criterions.destroy_all
     expect(subject.active?).to eq false
   end

   it "returns true otherwise" do
     expect(subject.active?).to eq true
   end
  end

  describe "copy_attributes" do
    let!(:search_criterion_template) { FactoryBot(:search_criterion, model_field_uid: "ent_cust_num") }
    let!(:search_criterion_rule) { FactoryBot(:search_criterion, model_field_uid: "ent_brok_ref") }
    let!(:rule) do
      r = ValidationRuleFieldFormat.new description: "rule descr", name: "rule name"
      r.search_criterions << search_criterion_rule
      r.save!
      r
    end
    let!(:template) do
      FactoryBot(:business_validation_template, delete_pending: true, description: "templ descr", disabled: true, module_type: "Entry",
                                             name: "templ name", private: true, search_criterions: [search_criterion_template],
                                             business_validation_rules: [rule])
    end

    it "hashifies attributes including rules, search criterions but skipping other external associations" do
      expect_any_instance_of(BusinessValidationRule).to receive(:copy_attributes).with(include_external: false).and_call_original
      attributes = template.copy_attributes["business_validation_template"]
      top_level_attr = attributes.reject { |k, _v| ["search_criterions", "business_validation_rules"].include? k }
      expect(top_level_attr).to eq({"description" => "templ descr", "module_type" => "Entry", "name" => "templ name", "private" => true})

      criterion_attr = attributes["search_criterions"].first["search_criterion"].select { |k, _v| k == "model_field_uid"}
      expect(criterion_attr).to eq({"model_field_uid" => "ent_cust_num"})

      rule_attr = attributes["business_validation_rules"].first["business_validation_rule"].select { |k, _v| ["type", "description"].include? k }
      expect(rule_attr).to eq({"type" => "ValidationRuleFieldFormat", "description" => "rule descr"})
    end

    it "includes external associations with rules if specified" do
      expect_any_instance_of(BusinessValidationRule).to receive(:copy_attributes).with(include_external: true)
      template.copy_attributes(include_external: true)
    end
  end

  describe "parse_copy_attributes" do
    it "instantiates template from attributes hash, including criterions, rules" do
      attributes = {"business_validation_template" =>
                     {"description" => "templ descr",
                      "search_criterions" =>
                       [{"search_criterion" =>
                          {"model_field_uid" => "ent_cust_num"}}],
                      "business_validation_rules" =>
                       [{"business_validation_rule" =>
                          {"description" => "rule descr",
                           "type" => "ValidationRuleFieldFormat",
                           "search_criterions" =>
                            [{"search_criterion" =>
                               {"model_field_uid" => "ent_brok_ref"}}]}}]}}

      template = described_class.parse_copy_attributes attributes
      expect(template.description).to eq "templ descr"
      templ_sc = template.search_criterions.first
      expect(templ_sc.model_field_uid).to eq "ent_cust_num"
      rule = template.business_validation_rules.first
      expect(rule.description).to eq "rule descr"
      rule_sc = rule.search_criterions.first
      expect(rule_sc.model_field_uid).to eq "ent_brok_ref"
    end
  end
end
