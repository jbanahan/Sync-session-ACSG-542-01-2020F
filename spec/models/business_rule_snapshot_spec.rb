require 'spec_helper'

describe BusinessRuleSnapshot do

  describe "create_from_entity" do
    let! (:business_rule_1) {
      t = BusinessValidationTemplate.create! name: "Test", module_type: "Entry", description: "Test Template"
      t.search_criterions.create! model_field_uid: "ent_brok_ref", operator: "notnull"

      t.business_validation_rules.create! type: "ValidationRuleFieldFormat", name: "Broker Reference", description: "Rule Description", notification_type: "Email", notification_recipients: "tufnel@stonehenge.biz", fail_state: "Fail", rule_attributes_json: {model_field_uid: "ent_brok_ref", regex: "REF"}.to_json
    }

    let! (:business_rule_2) {
      t = BusinessValidationTemplate.create! name: "Test 2", module_type: "Entry", description: "Test Template 2"
      t.search_criterions.create! model_field_uid: "ent_brok_ref", operator: "notnull"

      t.business_validation_rules.create! type: "ValidationRuleFieldFormat", name: "Broker Reference", description: "Rule Description 2", notification_type: nil, notification_recipients: nil, fail_state: "Fail", rule_attributes_json: {model_field_uid: "ent_brok_ref", regex: "ABC"}.to_json
    }

    let! (:entry) {
      Factory(:entry, broker_reference: "REF")
    }

    let (:user) {
      Factory(:user)
    }

    it "returns history data for given entity" do
      now = Time.zone.now
      # Timecop used so the rule's result changed/updated at values will be consistent with expectations
      Timecop.freeze(now) do
        BusinessValidationTemplate.create_all! run_validation: true
        # Make the second rule result be overridden
        result = entry.business_validation_results.where(business_validation_template_id: business_rule_2.business_validation_template.id).first
        rule_result = result.business_validation_rule_results.first
        rule_result.update_attributes! overridden_at: now, overridden_by: user, note: "I overrode it."
      end
      now_json = ActiveSupport::JSON.decode(now.to_json)

      snapshot_data = nil
      expect(BusinessRuleSnapshot).to receive(:write_to_s3) do |json, entity|
        expect(entity).to eq entry
        snapshot_data = ActiveSupport::JSON.decode json
        {bucket: "bucket", version: "version", key: "path/file.json"}
      end

      snapshot = BusinessRuleSnapshot.create_from_entity entry
      expect(snapshot.bucket).to eq "bucket"
      expect(snapshot.version).to eq "version"
      expect(snapshot.doc_path).to eq "path/file.json"
      expect(snapshot.recordable).to eq entry

      template_1 = business_rule_1.business_validation_template
      template_2 = business_rule_2.business_validation_template

      expect(snapshot_data).to eq({
        "recordable_id" => entry.id,
        "recordable_type" => "Entry",
        "templates" => {
          "template_#{template_1.id}" => {
            "name" => "Test",
            "description" => "Test Template",
            "state" => "Pass",
            "rules" => {
              "rule_#{business_rule_1.id}" => {
                "type" => "ValidationRuleFieldFormat",
                "name" => "Broker Reference",
                "description" => "Rule Description",
                "notification_type" => "Email",
                "fail_state" => "Fail",
                "state" => "Pass",
                "message" => nil,
                "note" => nil,
                "overridden_by_id" => nil,
                "overridden_at" => nil,
                "created_at" => now_json,
                "updated_at" => now_json
              }
            }
          },
          "template_#{template_2.id}" => {
            "name" => "Test 2",
            "description" => "Test Template 2",
            "state" => "Fail",
            "rules" => {
              "rule_#{business_rule_2.id}" => {
                "type" => "ValidationRuleFieldFormat",
                "name" => "Broker Reference",
                "description" => "Rule Description 2",
                "notification_type" => nil,
                "fail_state" => "Fail",
                "state" => "Fail",
                "message" => "Broker Reference must match 'ABC' format but was 'REF'.",
                "note" => "I overrode it.",
                "overridden_by_id" => user.id,
                "overridden_at" => now_json,
                "created_at" => now_json,
                "updated_at" => now_json
              }
            }
          }
        }
      })
    end

    it "writes snapshot failure when uploads to s3 fail" do
      json = {"json" => "data"}
      expect(described_class).to receive(:write_to_s3).and_raise Exception
      expect(described_class).to receive(:generate_snapshot_data).and_return(json)

      snapshot = BusinessRuleSnapshot.create_from_entity entry

      failure = EntitySnapshotFailure.where(snapshot_id: snapshot.id, snapshot_type: "BusinessRuleSnapshot").first
      expect(failure).not_to be_nil
      expect(failure.snapshot_json).to eq json.to_json
    end
  end

  describe "rule_comparisons" do
    let(:pass_snapshot) {
      {
        "recordable_id" => 11,
        "recordable_type" => "Entry",
        "templates" => {
          "template_1" => {
            "name" => "Test",
            "description" => "Test Template",
            "state" => "Pass",
            "rules" => {
              "rule_1" => {
                "type" => "ValidationRuleFieldFormat",
                "name" => "Broker Reference",
                "description" => "Rule Description",
                "notification_type" => nil,
                "fail_state" => "Fail",
                "state" => "Pass",
                "message" => nil,
                "note" => nil,
                "overridden_by_id" => nil,
                "overridden_at" => nil,
                "created_at" => "2016-08-08T20:34:12Z",
                "updated_at" => "2016-08-08T20:34:12Z"
              }
            }
          }
        }
      }.to_json
    }

    let(:fail_snapshot) {
      {
        "recordable_id" => 11,
        "recordable_type" => "Entry",
        "templates" => {
          "template_1" => {
            "name" => "Test",
            "description" => "Test Template",
            "state" => "Pass",
            "rules" => {
              "rule_1" => {
                "type" => "ValidationRuleFieldFormat",
                "name" => "Broker Reference",
                "description" => "Rule Description",
                "notification_type" => nil,
                "fail_state" => "Fail",
                "state" => "Fail",
                "message" => "Invalid data.",
                "note" => nil,
                "overridden_by_id" => nil,
                "overridden_at" => nil,
                "created_at" => "2016-08-09T20:34:12Z",
                "updated_at" => "2016-08-09T20:34:12Z"
              }
            }
          }
        }
      }.to_json
    }

    let(:override_snapshot) {
      {
        "recordable_id" => 11,
        "recordable_type" => "Entry",
        "templates" => {
          "template_1" => {
            "name" => "Test",
            "description" => "Test Template",
            "state" => "Pass",
            "rules" => {
              "rule_1" => {
                "type" => "ValidationRuleFieldFormat",
                "name" => "Broker Reference",
                "description" => "Rule Description",
                "notification_type" => nil,
                "fail_state" => "Fail",
                "state" => "Pass",
                "message" => "Invalid data.",
                "note" => "I don't care.",
                "overridden_by_id" => user.id,
                "overridden_at" => "2016-08-10T20:34:12Z",
                "created_at" => "2016-08-10T20:34:12Z",
                "updated_at" => "2016-08-10T20:34:12Z"
              }
            }
          }
        }
      }.to_json
    }

    let (:user) { Factory(:user) }
    let (:entry) { Factory(:entry) }

    it "returns comparisons over distinct rule state changes" do
      # Create 6 snapshot records (2 for each snapshot above) so it shows we're filtering out any that don't
      # have a state change
      snapshots = []
      6.times { snapshots << BusinessRuleSnapshot.create!(recordable_id: entry.id, recordable_type: "entry", bucket: "bucket", version: "version", doc_path: "path") }

      expect(described_class).to receive(:retrieve_snapshot_data_from_s3).ordered.with(snapshots[0]).and_return pass_snapshot
      expect(described_class).to receive(:retrieve_snapshot_data_from_s3).ordered.with(snapshots[1]).and_return pass_snapshot
      expect(described_class).to receive(:retrieve_snapshot_data_from_s3).ordered.with(snapshots[2]).and_return fail_snapshot
      expect(described_class).to receive(:retrieve_snapshot_data_from_s3).ordered.with(snapshots[3]).and_return fail_snapshot
      expect(described_class).to receive(:retrieve_snapshot_data_from_s3).ordered.with(snapshots[4]).and_return override_snapshot
      expect(described_class).to receive(:retrieve_snapshot_data_from_s3).ordered.with(snapshots[5]).and_return override_snapshot

      comparisons = described_class.rule_comparisons entry
      expect(comparisons.length).to eq 3

      expect(comparisons[0]).to eq({
        "template_name" => "Test",
        "template_description" => "Test Template",
        "type" => "ValidationRuleFieldFormat",
        "name" => "Broker Reference",
        "description" => "Rule Description",
        "notification_type" => nil,
        "fail_state" => "Fail",
        "state" => "Pass",
        "message" => nil,
        "note" => nil,
        "overridden_by_id" => nil,
        "overridden_at" => nil,
        "created_at" => "2016-08-08T20:34:12Z",
        "updated_at" => "2016-08-08T20:34:12Z"
      })

      expect(comparisons[1]).to eq({
        "template_name" => "Test",
        "template_description" => "Test Template",
        "type" => "ValidationRuleFieldFormat",
        "name" => "Broker Reference",
        "description" => "Rule Description",
        "notification_type" => nil,
        "fail_state" => "Fail",
        "state" => "Fail",
        "message" => "Invalid data.",
        "note" => nil,
        "overridden_by_id" => nil,
        "overridden_at" => nil,
        "created_at" => "2016-08-09T20:34:12Z",
        "updated_at" => "2016-08-09T20:34:12Z"
      })

      expect(comparisons[2]).to eq({
        "template_name" => "Test",
        "template_description" => "Test Template",
        "type" => "ValidationRuleFieldFormat",
        "name" => "Broker Reference",
        "description" => "Rule Description",
        "notification_type" => nil,
        "fail_state" => "Fail",
        "state" => "Pass",
        "message" => "Invalid data.",
        "note" => "I don't care.",
        "overridden_by_id" => user.id,
        "overridden_at" => "2016-08-10T20:34:12Z",
        "created_at" => "2016-08-10T20:34:12Z",
        "updated_at" => "2016-08-10T20:34:12Z"
      })
    end
  end
end
