describe BusinessValidationRule do
  describe "recipients_and_mailing_lists" do
    let(:bvt) { FactoryBot(:business_validation_template)}
    let(:bvru) do
      FactoryBot(:business_validation_rule, type: 'ValidationRuleEntryInvoiceLineFieldFormat',
                                         business_validation_template: bvt)
    end

    describe '#type_to_english' do
      it 'translates the type to the English equivalent' do
        expect(bvru.type_to_english).to eql('Entry Invoice Line Field Format')
      end
    end

    it 'defaults to returning notification_recipients' do
      bvru.notification_recipients = 'abc@domain.com, def@domain.com'
      bvru.save!
      bvru.reload
      expect(bvru.recipients_and_mailing_lists).to eql('abc@domain.com, def@domain.com')
    end

    it 'returns the mailing list emails if no notification_recipients are present' do
      mailing_list = FactoryBot(:mailing_list, user: FactoryBot(:user), name: 'mailing list', email_addresses: "fgh@domain.com, ghi@domain.com")
      bvru.notification_recipients = ""
      bvru.mailing_list = mailing_list
      bvru.save!
      bvru.reload
      expect(bvru.recipients_and_mailing_lists).to eql("fgh@domain.com, ghi@domain.com")
    end

    it 'appends mailing_list recipients to notification_recipients if a mailing_list is present and notification_recipients exist' do
      mailing_list = FactoryBot(:mailing_list, user: FactoryBot(:user), name: 'mailing list', email_addresses: "fgh@domain.com, ghi@domain.com")
      bvru.notification_recipients = 'abc@domain.com, def@domain.com'
      bvru.mailing_list = mailing_list
      bvru.save!
      bvru.reload
      expect(bvru.recipients_and_mailing_lists).to eql("abc@domain.com, def@domain.com, fgh@domain.com, ghi@domain.com")
    end
  end

  describe "enabled?" do
    it "does not return !enabled in subclasses_array" do
      expect(described_class.subclasses_array.find {|a| a[1] == 'PoloValidationRuleEntryInvoiceLineMatchesPoLine'}).to be_nil
    end

    it "returns when no enabled lambda in subclasses_array" do
      arr = described_class.subclasses_array
      expect(arr.find {|a| a[1] == 'ValidationRuleManual'}).not_to be_nil
    end
  end

  describe "should_skip?" do
    it "bases should_skip? on search_criterions" do
      pass_ent = Entry.new(entry_number: '9')
      fail_ent = Entry.new(entry_number: '7')
      bvr = described_class.new
      bvr.search_criterions.build(model_field_uid: 'ent_entry_num', operator: 'eq', value: '9')
      expect(bvr.should_skip?(pass_ent)).to be_falsey
      expect(bvr.should_skip?(fail_ent)).to be_truthy
    end

    it "raises exception if search_criterion's model field CoreModule doesn't equal object's CoreModule" do
      bvr = described_class.new
      bvr.search_criterions.build(model_field_uid: 'ent_entry_num', operator: 'eq', value: '9')
      ci = CommercialInvoiceLine.new
      expect {bvr.should_skip? ci}.to raise_error(/Invalid object expected Entry got CommercialInvoiceLine/)
    end
  end

  describe "destroy" do
    it "destroys record" do
      rule = FactoryBot(:business_validation_rule)
      rule.destroy
      expect(described_class.count).to eq 0
    end

    context "validate result deletes", :disable_delayed_jobs do

      it "destroys validation rule and dependents" do
        rule_result = FactoryBot(:business_validation_rule_result)
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
        expect(subject.flag?("value")).to eq true
      end
    end

    [false, "0", "false", nil].each do |v|
      it "returns false of attribute flag value is set with boolean false value #{v}" do
        subject.rule_attributes_json = {value: v}.to_json
        expect(subject.flag?("value")).to eq false
      end
    end

    it "returns false if flag is not set" do
      expect(subject.flag?("value")).to eq false
    end

  end

  describe "active?" do
    let(:bvt) { FactoryBot(:business_validation_template)}
    let(:bvru) { FactoryBot(:business_validation_rule, business_validation_template: bvt, disabled: false, delete_pending: false)}

    before { allow(bvt).to receive(:active?).and_return true }

    it "returns false if disabled" do
      bvru.update! disabled: true
      expect(bvru.active?).to eq false
    end

    it "returns false if delete_pending" do
      bvru.update! delete_pending: true
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

  describe "copy_attributes" do
    let!(:group) { FactoryBot(:group) }
    let!(:mailing_list) { FactoryBot(:mailing_list) }
    let!(:search_criterion) { FactoryBot(:search_criterion, model_field_uid: "ent_cust_num", operator: "eq", value: "lumber")}
    let(:rule) do
      r = ValidationRuleFieldFormat.new description: "descr", fail_state: "Fail", group_id: group.id,
                                        mailing_list_id: mailing_list.id, message_pass: "mess pass", message_review_fail: "mess rev/fail",
                                        message_skipped: "mess skip", name: "rule name", notification_recipients: "tufnel@stonehenge.biz",
                                        notification_type: "email", rule_attributes_json: "JSON", subject_pass: "sub pass",
                                        subject_review_fail: "sub review/fail", subject_skipped: "sub skip", suppress_pass_notice: true,
                                        suppress_review_fail_notice: true, suppress_skipped_notice: true
      r.search_criterions << search_criterion
      r.save!
      r
    end

    it "hashifies attributes including search criterions but skipping other external associations" do

      attributes = {"business_validation_rule" =>
                     {"bcc_notification_recipients" => nil,
                      "cc_notification_recipients" => nil,
                      "description" => "descr",
                      "fail_state" => "Fail",
                      "message_pass" => "mess pass",
                      "message_review_fail" => "mess rev/fail",
                      "message_skipped" => "mess skip",
                      "name" => "rule name",
                      "notification_recipients" => "tufnel@stonehenge.biz",
                      "notification_type" => "email",
                      "rule_attributes_json" => "JSON",
                      "subject_pass" => "sub pass",
                      "subject_review_fail" => "sub review/fail",
                      "subject_skipped" => "sub skip",
                      "suppress_pass_notice" => true,
                      "suppress_review_fail_notice" => true,
                      "suppress_skipped_notice" => true,
                      "type" => "ValidationRuleFieldFormat",
                      "search_criterions" =>
                       [{"search_criterion" =>
                          {"include_empty" => nil,
                           "model_field_uid" => "ent_cust_num",
                           "operator" => "eq",
                           "secondary_model_field_uid" => nil,
                           "value" => "lumber"}}]}}

      expect(rule.copy_attributes).to eq attributes
    end

    it "handles rules with extended classnames" do
      r = described_class.new type: "OpenChain::CustomHandler::AnnInc::AnnValidationRuleProductTariffPercentOfValueSet"

      expect(r.copy_attributes["business_validation_rule"]["type"]).to eq "OpenChain::CustomHandler::AnnInc::AnnValidationRuleProductTariffPercentOfValueSet"
    end

    it "includes other external associations if specified" do
      attributes = rule.copy_attributes(include_external: true)["business_validation_rule"]
      expect(attributes["mailing_list_id"]).to eq mailing_list.id
      expect(attributes["group_id"]).to eq group.id
    end
  end

  describe "parse_copy_attributes" do
    it "instantiates rule from attributes hash, including criterions" do
      attributes = {"business_validation_rule" =>
                     {"description" => "descr",
                      "type" => "ValidationRuleFieldFormat",
                      "search_criterions" =>
                       [{"search_criterion" =>
                          {"model_field_uid" => "ent_cust_num"}}]}}

      rule = described_class.parse_copy_attributes attributes
      expect(rule.type).to eq "ValidationRuleFieldFormat"
      expect(rule.description).to eq "descr"
      sc = rule.search_criterions.first
      expect(sc.model_field_uid).to eq "ent_cust_num"
    end
  end

end
