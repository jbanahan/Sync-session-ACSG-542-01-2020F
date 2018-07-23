describe OpenChain::EntityCompare::BusinessRuleComparator::BusinessRuleNotificationComparator do
  before { stub_master_setup }
  let(:co) { Factory(:company, name: "ACME") }
  let(:entry) { Factory(:entry, broker_reference: "brok ref", importer: co, customer_number: "cust num") }              
  let(:url) { Rails.application.routes.url_helpers.entry_url(entry.id, host: MasterSetup.get.request_host, protocol: 'http' ) }
  let(:bvre) { Factory(:business_validation_result, validatable: entry)}
  let(:bvru_1) { Factory(:business_validation_rule, notification_recipients: "tufnel@stonehenge.biz", suppress_pass_notice: false, suppress_review_fail_notice: false, suppress_skipped_notice: false) }
  let(:bvru_2) { Factory(:business_validation_rule, notification_recipients: "tufnel@stonehenge.biz", suppress_pass_notice: false, suppress_review_fail_notice: false, suppress_skipped_notice: false) }
  let!(:bvrr_1) { Factory(:business_validation_rule_result_without_callback, business_validation_rule: bvru_1, business_validation_result: bvre) }
  let!(:bvrr_2) { Factory(:business_validation_rule_result_without_callback, business_validation_rule: bvru_2, business_validation_result: bvre) }
  let!(:old_json) do
    {
    recordable_type: "Entry",
    recordable_id: entry.id,
    templates: {
        template_1: {
            rules: {
                "rule_#{bvru_1.id}".to_sym => {                    
                    description: "old descr 1",
                    message: "old msg 1",
                    notification_type: "email",
                    state: "Pass"              
                },
                "rule_#{bvru_2.id}".to_sym => {                  
                    description: "old descr 2",
                    message: "old msg 2",
                    notification_type: "email",
                    state: "Pass"
                }}}}}.with_indifferent_access
  end
  let!(:old_rules) { old_json[:templates][:template_1][:rules] }
  let(:old_rule_1) { old_rules["rule_#{bvru_1.id}".to_sym] }
  let(:old_rule_2) { old_rules["rule_#{bvru_2.id}".to_sym] }

  let!(:new_json) do
    {
    recordable_type: "Entry",
    recordable_id: entry.id,
    templates: {
        template_1: {
            rules: {
                "rule_#{bvru_1.id}".to_sym => {                    
                    description: "new descr 1",
                    message: "new msg 1",
                    notification_type: "Email",
                    state: "Fail"              
                },
                "rule_#{bvru_2.id}".to_sym => {                  
                    description: "new descr 2",
                    message: "new msg 2",
                    notification_type: "Email",
                    state: "Fail"
                }}}}}.with_indifferent_access
  end
  let!(:new_rules) { new_json[:templates][:template_1][:rules] }
  let(:new_rule_1) { new_rules["rule_#{bvru_1.id}".to_sym] }
  let(:new_rule_2) { new_rules["rule_#{bvru_2.id}".to_sym] }

  describe "compare" do   
    it "notifies separately for each rule with a changed status" do
      expect(described_class).to receive(:get_json_hash).with('old bucket', 'old key', 'old version').and_return old_json
      expect(described_class).to receive(:get_json_hash).with('new bucket', 'new key', 'new version').and_return new_json
      expect(described_class).to receive(:send_email).with(id: entry.id, rule: bvru_1, uid: "brok ref", :module_type=>"Entry", state: "Fail", 
                                                           importer_name: "ACME", customer_number: "cust num", description: "new descr 1", message: "new msg 1")
      expect(described_class).to receive(:send_email).with(id: entry.id, rule: bvru_2, uid: "brok ref", :module_type=>"Entry", state: "Fail", 
                                                           importer_name: "ACME", customer_number: "cust num", description: "new descr 2", message: "new msg 2")
      described_class.compare 'Entry', entry.id, 'old bucket', 'old key', 'old version', 'new bucket', 'new key', 'new version'
    end

    it "notifies with nil customer number for non-entry" do
      prod = Factory(:product, unique_identifier: "prod uid", importer: co)
      bvre.update_attributes! validatable: prod
      old_json[:recordable_type] = new_json[:recordable_type] = "Product"
      old_json[:recordable_id] = new_json[:recordable_id] = prod.id
      new_rules.delete("rule_#{bvru_2.id}".to_sym) 
      old_rules.delete("rule_#{bvru_2.id}".to_sym)
      expect(described_class).to receive(:get_json_hash).with('old bucket', 'old key', 'old version').and_return old_json
      expect(described_class).to receive(:get_json_hash).with('new bucket', 'new key', 'new version').and_return new_json
      expect(described_class).to receive(:send_email).with(id: prod.id, rule: bvru_1, uid: "prod uid", :module_type=>"Product", state: "Fail", importer_name: "ACME", 
                                                           customer_number: nil, description: "new descr 1", message: "new msg 1")
      described_class.compare "Product", prod.id, 'old bucket', 'old key', 'old version', 'new bucket', 'new key', 'new version'
    end

    it "notifies with nil importer if not linked to importer" do
      entry.update_attributes! importer: nil
      new_rules.delete("rule_#{bvru_2.id}".to_sym) 
      old_rules.delete("rule_#{bvru_2.id}".to_sym)
      expect(described_class).to receive(:get_json_hash).with('old bucket', 'old key', 'old version').and_return old_json
      expect(described_class).to receive(:get_json_hash).with('new bucket', 'new key', 'new version').and_return new_json
      expect(described_class).to receive(:send_email).with(id: entry.id, rule: bvru_1, uid: "brok ref", :module_type=>"Entry", state: "Fail", importer_name: nil, 
                                                           customer_number: "cust num", description: "new descr 1", message: "new msg 1")
      described_class.compare "Entry", entry.id, 'old bucket', 'old key', 'old version', 'new bucket', 'new key', 'new version'
    end
  end

  describe "rules_for_processing" do
    it "returns nil if JSON is nil" do
      expect(described_class.rules_for_processing nil).to be_nil
    end

    it "returns hash of rules eligible for notification, adding rule id" do
      old_rule_1.delete(:notification_type)
      expected = {"rule_#{bvru_2.id}" => { "id" => bvru_2.id, "description" => "old descr 2", "message" => "old msg 2", "notification_type" => "email", "state" => "Pass" }}
      expect(described_class.rules_for_processing old_json).to eq expected
    end
  end

  describe "changed_rules" do
    let (:old_r) do
      {
        "rule_#{bvru_1.id}" => old_rule_1,
        "rule_#{bvru_2.id}" => old_rule_2,
      }
    end

    let (:new_r) do
      {
        "rule_#{bvru_1.id}" => new_rule_1,
        "rule_#{bvru_2.id}" => new_rule_2,
      }
    end

    it "returns only rules with 'Fail' or 'Review' if old snapshot is nil" do
      new_rule_1["state"] = "Pass"
      expect(described_class.changed_rules nil, new_r).to eq [new_rule_2]

      new_rule_1["state"] = "Skipped"
      expect(described_class.changed_rules nil, new_r).to eq [new_rule_2]

      new_rule_1["state"] = "Fail"
      expect(described_class.changed_rules nil, new_r).to eq [new_rule_1, new_rule_2]
      
      new_rule_1["state"] = "Review"
      expect(described_class.changed_rules nil, new_r).to eq [new_rule_1, new_rule_2]
    end

    it "omits rules with identical results" do
      old_rule_1["state"] = "Fail"
      new_rule_1["state"] = "Fail"
      expect(described_class.changed_rules old_r, new_r).to eq [new_rule_2]

      old_rule_1["state"] = "Pass"
      new_rule_1["state"] = "Pass"
      expect(described_class.changed_rules old_r, new_r).to eq [new_rule_2]

      old_rule_1["state"] = "Review"
      new_rule_1["state"] = "Review"
      expect(described_class.changed_rules old_r, new_r).to eq [new_rule_2]

      old_rule_1["state"] = "Skipped"
      new_rule_1["state"] = "Skipped"
      expect(described_class.changed_rules old_r, new_r).to eq [new_rule_2]
    end

    it "omits rules whose results change between 'Skipped' and 'Pass'" do
      old_rule_1["state"] = "Skipped"
      new_rule_1["state"] = "Pass"
      expect(described_class.changed_rules old_r, new_r).to eq [new_rule_2]

      old_rule_1["state"] = "Pass"
      new_rule_1["state"] = "Skipped"
      expect(described_class.changed_rules old_r, new_r).to eq [new_rule_2]
    end

    it "returns rules with changed results involving a 'Fail'/'Review' state" do
      old_rule_1["state"] = "Skipped"
      new_rule_1["state"] = "Fail"
      expect(described_class.changed_rules old_r, new_r).to eq [new_rule_1, new_rule_2]

      old_rule_1["state"] = "Fail"
      new_rule_1["state"] = "Skipped"
      expect(described_class.changed_rules old_r, new_r).to eq [new_rule_1, new_rule_2]

      old_rule_1["state"] = "Skipped"
      new_rule_1["state"] = "Review"
      expect(described_class.changed_rules old_r, new_r).to eq [new_rule_1, new_rule_2]

      old_rule_1["state"] = "Review"
      new_rule_1["state"] = "Skipped"
      expect(described_class.changed_rules old_r, new_r).to eq [new_rule_1, new_rule_2]

      old_rule_1["state"] = "Fail"
      new_rule_1["state"] = "Pass"
      expect(described_class.changed_rules old_r, new_r).to eq [new_rule_1, new_rule_2]

      # Pass -> Fail already accounted for in rule 2

      old_rule_1["state"] = "Pass"
      new_rule_1["state"] = "Review"
      expect(described_class.changed_rules old_r, new_r).to eq [new_rule_1, new_rule_2]

      old_rule_1["state"] = "Review"
      new_rule_1["state"] = "Pass"
      expect(described_class.changed_rules old_r, new_r).to eq [new_rule_1, new_rule_2]

      old_rule_1["state"] = "Review"
      new_rule_1["state"] = "Fail"
      expect(described_class.changed_rules old_r, new_r).to eq [new_rule_1, new_rule_2]

      old_rule_1["state"] = "Fail"
      new_rule_1["state"] = "Review"
      expect(described_class.changed_rules old_r, new_r).to eq [new_rule_1, new_rule_2]
    end

    it "returns only rules with 'Fail' or 'Review' if old rule is missing from old snapshot" do
      old_r.delete("rule_#{bvru_1.id}")
      old_r.delete("rule_#{bvru_2.id}")
      new_rule_1["state"] = "Pass"
      expect(described_class.changed_rules old_r, new_r).to eq [new_rule_2]

      new_rule_1["state"] = "Skipped"
      expect(described_class.changed_rules old_r, new_r).to eq [new_rule_2]

      new_rule_1["state"] = "Review"
      expect(described_class.changed_rules old_r, new_r).to eq [new_rule_1, new_rule_2]
    end
  end

  describe "update" do
    let(:rule) { {"id" => bvru_1.id, "notification_type" => "Email", "state" => "Pass", "description" => "descr", "message" => "msg"} }
    
    it "sends email if indicated" do
      expect(described_class).to receive(:send_email).with(id: bvru_1.id, rule: bvru_1, module_type: "Entry", uid: "brok ref", state: "Pass", 
                                                           description: "descr", message: "msg", customer_number: "cust num", importer_name: "ACME")
      described_class.update rule, "Entry", bvru_1.id, "brok ref", "cust num", "ACME"
    end

    it "doesn't send email if not indicated" do
      rule["notification_type"] = "Telepathy"
      expect(described_class).to_not receive(:send_email)
      described_class.update rule, "Entry", bvru_1.id, "brok ref", "cust num", "ACME"
    end
  end

  describe "send_email" do
    it "sends email without customized subject/body" do
      described_class.send_email(id: entry.id, rule: bvru_1, uid: "brok ref", :module_type=>"Entry", state: "Fail", importer_name: "ACME", 
                                 customer_number: "cust num", description: "new descr 1", message: "new msg 1")

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["tufnel@stonehenge.biz"]
      expect(mail.subject).to eq "Entry - brok ref - Fail: new descr 1"
      expect(mail.body).to include "cust num"
      expect(mail.body).to include "ACME"
      expect(mail.body).to include "Rule Description: new descr 1"
      expect(mail.body).to include "Entry brok ref rule status has changed to 'Fail'"
      expect(mail.body).to include "new msg 1"
      expect(mail.body).to include url
    end

    context "Review/Fail" do
      it "sends email with customized subject/body" do
        bvru_1.update_attributes! subject_review_fail: "Custom fail subject", message_review_fail: "Custom fail message"
        described_class.send_email(id: entry.id, rule: bvru_1, uid: "brok ref", :module_type=>"Entry", state: "Fail", importer_name: "ACME", 
                                   customer_number: "cust num", description: "new descr 1", message: "new msg 1")

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.subject).to eq "Entry - brok ref - Fail: Custom fail subject"
        expect(mail.body).to include "Custom fail message"
        expect(mail.body).to include "Entry brok ref rule status has changed to 'Fail'"
      end
      
      it "doesn't send if disabled" do
        bvru_1.update_attributes! suppress_review_fail_notice: true
        described_class.send_email(id: entry.id, rule: bvru_1, uid: "brok ref", :module_type=>"Entry", state: "Review", importer_name: "ACME", 
                                   customer_number: "cust num", description: "new descr 1", message: "new msg 1")

        expect(ActionMailer::Base.deliveries.pop).to eq nil
      end
    end

    context "Pass" do
      it "sends email with customized subject/body" do
        bvru_1.update_attributes! subject_pass: "Custom pass subject", message_pass: "Custom pass message"
        described_class.send_email(id: entry.id, rule: bvru_1, uid: "brok ref", :module_type=>"Entry", state: "Pass", importer_name: "ACME", 
                                   customer_number: "cust num", description: "new descr 1", message: "new msg 1")

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.subject).to eq "Entry - brok ref - Pass: Custom pass subject"
        expect(mail.body).to include "Custom pass message"
        expect(mail.body).to include "Entry brok ref rule status has changed to 'Pass'"
      end

      it "doesn't send if disabled" do
        bvru_1.update_attributes! suppress_pass_notice: true
        described_class.send_email(id: entry.id, rule: bvru_1, uid: "brok ref", :module_type=>"Entry", state: "Pass", importer_name: "ACME", 
                                   customer_number: "cust num", description: "new descr 1", message: "new msg 1")

        expect(ActionMailer::Base.deliveries.pop).to eq nil
      end
    end

    context "Skipped" do
      it "sends email with customized subject/body" do
        bvru_1.update_attributes! subject_skipped: "Custom skipped subject", message_skipped: "Custom skipped message"
        described_class.send_email(id: entry.id, rule: bvru_1, uid: "brok ref", :module_type=>"Entry", state: "Skipped", importer_name: "ACME", 
                                   customer_number: "cust num", description: "new descr 1", message: "new msg 1")

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.subject).to eq "Entry - brok ref - Skipped: Custom skipped subject"
        expect(mail.body).to include "Custom skipped message"
        expect(mail.body).to include "Entry brok ref rule status has changed to 'Skipped'"
      end

      it "doesn't send if disabled" do
        bvru_1.update_attributes! suppress_skipped_notice: true
        described_class.send_email(id: entry.id, rule: bvru_1, uid: "brok ref", :module_type=>"Entry", state: "Skipped", importer_name: "ACME", 
                                   customer_number: "cust num", description: "new descr 1", message: "new msg 1")

        expect(ActionMailer::Base.deliveries.pop).to eq nil
      end
    end

  end

  describe "accept?" do
    subject { described_class }

    let (:entry) {
      Factory(:entry)
    }

    let (:business_validation_rule_result) {
      result = Factory(:business_validation_rule_result)
      entry.business_validation_results << result.business_validation_result

      result
    }

    let (:business_validation_rule) {
      business_validation_rule_result.business_validation_rule
    }

    let (:snapshot) {
      BusinessRuleSnapshot.new recordable: entry
    }

    it "accepts snapshots for any objects that have rules with notifications configured" do
      business_validation_rule.update_attributes! notification_type: "email"
      expect(subject.accept? snapshot).to eq true
    end

    it "does not accept snapshots for any object that does not have a notification type" do
      expect(subject.accept? snapshot).to eq false
    end
  end

end
