describe OpenChain::EntityCompare::TimedBusinessRuleComparator do
  describe "compare" do
    let(:now) { Time.zone.parse("2018-01-10") }
    let(:entry) { create(:entry, release_date: DateTime.new(2018, 3, 15, 12), duty_due_date: DateTime.new(2018, 2, 10, 12), customer_number: "ACME") }
    let!(:schedule) { create(:business_validation_schedule, model_field_uid: "ent_release_date", operator: "After", num_days: 3) }
    let!(:criterion1) { create(:search_criterion, business_validation_schedule: schedule, model_field_uid: "ent_cust_num", operator: "eq", value: "ACME") }
    let!(:schedule2) { create(:business_validation_schedule, model_field_uid: "ent_duty_due_date", operator: "Before", num_days: 5) }
    let!(:criterion2) { create(:search_criterion, business_validation_schedule: schedule2, model_field_uid: "ent_cust_num", operator: "eq", value: "ACME") }

    it "sets date for running of business rules for each schedule associated with a schedule" do
      Timecop.freeze(now) do
        described_class.compare("Entry", entry.id, "old_bucket", "old_path", "old_version", "new_bucket", "new_path", "new_version")
      end
      schedule.reload
      expect(schedule.business_validation_scheduled_jobs.count).to eq 1
      job = schedule.business_validation_scheduled_jobs.first
      expect(job.validatable).to eq entry
      expect(job.run_date).to eq DateTime.new(2018, 3, 18, 12, 0, 0)

      schedule2.reload
      expect(schedule2.business_validation_scheduled_jobs.count).to eq 1
      job = schedule2.business_validation_scheduled_jobs.first
      expect(job.validatable).to eq entry
      expect(job.run_date).to eq ActiveSupport::TimeZone[Time.zone.name].local(2018, 2, 4)
    end

    it "replaces date if already set for a particular schedule" do
      create(:business_validation_scheduled_job, business_validation_schedule: schedule, validatable: entry, run_date: Date.new(2018, 4, 1))
      schedule.num_days = 10; schedule.operator = "Before"; schedule.save!
      Timecop.freeze(now) do
        described_class.compare("Entry", entry.id, "old_bucket", "old_path", "old_version", "new_bucket", "new_path", "new_version")
      end

      expect(schedule.business_validation_scheduled_jobs.count).to eq 1

      job = schedule.business_validation_scheduled_jobs.first
      expect(job.validatable).to eq entry
      expect(job.run_date).to eq DateTime.new(2018, 3, 5, 11, 59, 59)
    end

    it "doesn't set date if not all search criterions are satisfied" do
      schedule.search_criterions.create! model_field_uid: "ent_cust_name", operator: "eq", value: "Acme"
      Timecop.freeze(now) do
        described_class.compare("Entry", entry.id, "old_bucket", "old_path", "old_version", "new_bucket", "new_path", "new_version")
      end
      expect(BusinessValidationScheduledJob.count).to eq 1
    end

    it "doesn't set date if it has already passed" do
      Timecop.freeze(DateTime.new 2018, 5, 1) do
        described_class.compare("Entry", entry.id, "old_bucket", "old_path", "old_version", "new_bucket", "new_path", "new_version")
      end
      schedule.reload
      expect(schedule.business_validation_scheduled_jobs.count).to eq 0
    end

    context "missing fields" do
      it "skips schedule if there are no search criterions" do
        schedule.search_criterions.destroy_all
        Timecop.freeze(now) do
          described_class.compare("Entry", entry.id, "old_bucket", "old_path", "old_version", "new_bucket", "new_path", "new_version")
        end
        schedule.reload
        expect(schedule.business_validation_scheduled_jobs.count).to eq 0
      end

      it "skips schedule if there's no model_field_uid" do
        schedule.update_attributes! model_field_uid: ""
        Timecop.freeze(now) do
          described_class.compare("Entry", entry.id, "old_bucket", "old_path", "old_version", "new_bucket", "new_path", "new_version")
        end
        schedule.reload
        expect(schedule.business_validation_scheduled_jobs.count).to eq 0
      end

      it "skips schedule if there's no operator" do
        schedule.update_attributes! operator: ""
        Timecop.freeze(now) do
          described_class.compare("Entry", entry.id, "old_bucket", "old_path", "old_version", "new_bucket", "new_path", "new_version")
        end
        schedule.reload
        expect(schedule.business_validation_scheduled_jobs.count).to eq 0
      end
    end
  end
end
