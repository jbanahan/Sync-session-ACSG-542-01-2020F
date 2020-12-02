class TestSchedulable
  def self.run_schedulable a; end
end

class TestSchedulableNoParams
  def self.run_schedulable; end
end

class BadSchedulable
end

describe SchedulableJob do
  describe '.create_default_jobs!' do
    jobs = ["OpenChain::StatClient", "OpenChain::IntegrationClient", "BusinessValidationTemplate", "SurveyResponseUpdate",
            "OfficialTariff", "OpenChain::Purge",
            "OpenChain::LoadCountriesSchedulableJob", "OpenChain::Report::MonthlyUserAuditReport",
            "OpenChain::BusinessRulesNotifier", "OpenChain::GoogleAccountChecker", "OpenChain::InactiveAccountChecker"]
    jobs.each do |klass|
      it "creates a default job for #{klass}" do
        described_class.create_default_jobs!
        expect(described_class.where(run_class: klass).first).not_to be_nil
      end
    end
  end

  describe "run" do
    let(:sj) {create(:schedulable_job, run_class: "TestSchedulable", log_runtime: false)}

    it "does not save a runtime by default" do
      sj.run
      expect(RuntimeLog.where(runtime_logable: sj).first).to be_nil
    end

    it "saves a runtime log when set" do
      sj.log_runtime = true
      sj.run
      expect(RuntimeLog.where(runtime_logable: sj).first).not_to be_nil
    end

    it "submits job" do
      expect(TestSchedulable).to receive(:run_schedulable).with({'last_start_time' => nil})
      sj.run
    end

    it "submits options" do
      opts = {a: "b"}.to_json
      expect(TestSchedulable).to receive(:run_schedulable).with('last_start_time' => nil, 'a' => 'b')
      sj = described_class.new(run_class: "TestSchedulable", opts: opts)
      sj.run
    end

    it "submits options that are non-hash json objects" do
      opts = ["A", "B"].to_json
      expect(TestSchedulable).to receive(:run_schedulable).with(["A", "B"])
      sj.opts = opts
      sj.run
    end

    it "emails when successful" do
      opts = {a: "b"}.to_json
      expect(TestSchedulable).to receive(:run_schedulable).with("last_start_time" => nil, 'a' => 'b')
      sj = described_class.new(run_class: "TestSchedulable", opts: opts, success_email: "success1@email.com,success2@email.com")
      sj.run

      m = OpenMailer.deliveries.pop
      expect(m.to.first).to eq("success1@email.com")
      expect(m.to.last).to eq("success2@email.com")
      expect(m.subject).to eq("[VFI Track] Scheduled Job Succeeded")
    end

    it "emails when unsuccessful" do
      opts = {a: "b"}.to_json
      allow(TestSchedulable).to receive(:run_schedulable).and_raise(NameError)
      sj = described_class.new(run_class: "TestSchedulable", opts: opts, failure_email: "failure1@email.com,failure2@email.com")

      sj.run

      m = OpenMailer.deliveries.pop
      expect(m.to.first).to eq("failure1@email.com")
      expect(m.to.last).to eq("failure2@email.com")
      expect(m.subject).to eq("[VFI Track] Scheduled Job Failed")
    end

    it "runs run_schedulable method without params" do
      opts = {a: "b"}.to_json
      sj = described_class.new(run_class: "TestSchedulableNoParams", opts: opts, success_email: "me@there.com")
      sj.run

      m = OpenMailer.deliveries.pop
      expect(m.to.first).to eq "me@there.com"
    end

    it "does not attempt to run classes with no run_schedulable method" do
      sj = described_class.new(run_class: "BadSchedulable", opts: {}, failure_email: "me@there.com")
      sj.run

      m = OpenMailer.deliveries.pop
      expect(m.to.first).to eq "me@there.com"
      expect(m.subject).to include "Failed"
      expect(m.body.raw_source).to include "No 'run_schedulable' method exists on 'BadSchedulable' class."
    end

    it "logs an error if no error email is configured" do
      opts = {'last_start_time' => nil, 'a' => "b"}
      e = StandardError.new "Message"
      allow(TestSchedulable).to receive(:run_schedulable).and_raise(e)

      sj = described_class.new(run_class: "TestSchedulable", opts: opts.to_json)
      sj.run

      expect(ErrorLogEntry.last.additional_messages).to eq ["Scheduled job for TestSchedulable with options #{opts} has failed"]
    end

    it "sets current schedulable job and clears it after run" do
      sj = described_class.new(run_class: "TestSchedulable")
      expect(described_class.current).to be_nil
      allow(TestSchedulable).to receive(:run_schedulable) do
        expect(described_class.current).to eq sj
        expect(described_class.running_as_scheduled_job?).to eq true
      end

      sj.run
      expect(described_class.current).to be_nil
      expect(described_class.running_as_scheduled_job?).to eq false
    end

    it "sets current schedulable job and clears it after run, even if error is raised" do
      sj = described_class.new(run_class: "TestSchedulable")
      expect(described_class.current).to be_nil
      allow(TestSchedulable).to receive(:run_schedulable) do
        expect(described_class.current).to eq sj
        raise "Error"
      end

      sj.run
      expect(described_class.current).to be_nil
    end
  end

  describe "time_zone" do
    it "defaults to eastern" do
      expect(described_class.new.time_zone).to eq(ActiveSupport::TimeZone["Eastern Time (US & Canada)"])
    end

    it "overrides" do
      expect(described_class.new(time_zone_name: "American Samoa").time_zone).to eq(ActiveSupport::TimeZone["American Samoa"]) # Tony Rocky Horror
    end

    it "fails on bad tz" do
      expect do
        described_class.new(time_zone_name: "BAD").time_zone
      end.to raise_error "Invalid time zone name: BAD"
    end
  end

  describe "run_class_name" do
    let (:job) { described_class.new job_class}

    it "strips module information from job class" do
      expect(described_class.new(run_class: "ModuleA::ModuleB::ClassName").run_class_name).to eq "ClassName"
    end

    it "handles blank run class" do
      expect(described_class.new.run_class_name).to eq ""
    end

    it "handles run classes without modules" do
      expect(described_class.new(run_class: "ClassName").run_class_name).to eq "ClassName"
    end
  end
end
