require 'spec_helper'

describe SchedulableJob do

  describe '.create_default_jobs!' do
    jobs = ["OpenChain::StatClient", "OpenChain::IntegrationClient", "BusinessValidationTemplate", "SurveyResponseUpdate",
            "OfficialTariff", "Message", "ReportResult", "OpenChain::WorkflowProcessor", "OpenChain::DailyTaskEmailJob",
            "OpenChain::LoadCountriesSchedulableJob", "OpenChain::Report::MonthlyUserAuditReport",
            "OpenChain::BusinessRulesNotifier"]
    jobs.each do |klass|
      it "creates a default job for #{klass}" do
        SchedulableJob.create_default_jobs!
        expect(SchedulableJob.where(run_class: klass).first).not_to be_nil
      end
    end
  end

  describe "run" do
    class TestSchedulable
    end

    class TestSchedulableNoParams
      def self.run_schedulable; end
    end
    it "should submit job" do
      expect(TestSchedulable).to receive(:run_schedulable).with({'last_start_time'=>nil})
      sj = SchedulableJob.new(:run_class=>"TestSchedulable")
      sj.run
    end
    it "should submit options" do
      opts = {:a=>"b"}.to_json
      expect(TestSchedulable).to receive(:run_schedulable).with('last_start_time'=>nil,'a'=>'b')
      sj = SchedulableJob.new(:run_class=>"TestSchedulable",:opts=>opts)
      sj.run
    end
    it "should email when successful" do
      opts = {:a=>"b"}.to_json
      expect(TestSchedulable).to receive(:run_schedulable).with("last_start_time"=>nil,'a'=>'b')
      sj = SchedulableJob.new(:run_class=>"TestSchedulable",:opts=>opts, success_email: "success1@email.com,success2@email.com")
      sj.run

      m = OpenMailer.deliveries.pop
      expect(m.to.first).to eq("success1@email.com")
      expect(m.to.last).to eq("success2@email.com")
      expect(m.subject).to eq("[VFI Track] Scheduled Job Succeeded")
    end
    it "should email when unsuccessful" do
      opts = {:a=>"b"}.to_json
      allow(TestSchedulable).to receive(:run_schedulable).and_raise(NameError)
      sj = SchedulableJob.new(:run_class=>"TestSchedulable",:opts=>opts, failure_email: "failure1@email.com,failure2@email.com")

      sj.run

      m = OpenMailer.deliveries.pop
      expect(m.to.first).to eq("failure1@email.com")
      expect(m.to.last).to eq("failure2@email.com")
      expect(m.subject).to eq("[VFI Track] Scheduled Job Failed")
    end
    it "should run run_schedulable method without params" do
      opts = {:a=>"b"}.to_json
      sj = SchedulableJob.new(:run_class=>"TestSchedulableNoParams",:opts=>opts, success_email: "me@there.com")
      sj.run

      m = OpenMailer.deliveries.pop
      expect(m.to.first).to eq "me@there.com"
    end
    it "should not attempt to run classes with no run_schedulable method" do
      sj = SchedulableJob.new(:run_class=>"TestSchedulable",:opts=>{}, failure_email: "me@there.com")
      sj.run

      m = OpenMailer.deliveries.pop
      expect(m.to.first).to eq "me@there.com"
      expect(m.subject).to include "Failed"
      expect(m.body.raw_source).to include "No 'run_schedulable' method exists on 'TestSchedulable' class."
    end
    it "should log an error if no error email is configured" do
      opts = {'last_start_time'=>nil,'a'=>"b"}
      e = StandardError.new "Message"
      allow(TestSchedulable).to receive(:run_schedulable).and_raise(e)

      sj = SchedulableJob.new(:run_class=>"TestSchedulable",:opts=>opts.to_json)
      sj.run

      expect(ErrorLogEntry.last.additional_messages).to eq ["Scheduled job for TestSchedulable with options #{opts} has failed"]
    end
  end

  describe "time_zone" do
    it "should default to eastern" do
      expect(SchedulableJob.new.time_zone).to eq(ActiveSupport::TimeZone["Eastern Time (US & Canada)"])
    end
    it "should override" do
      expect(SchedulableJob.new(:time_zone_name=>"American Samoa").time_zone).to eq(ActiveSupport::TimeZone["American Samoa"]) #Tony Rocky Horror
    end
    it "should fail on bad tz" do
      expect {
        SchedulableJob.new(:time_zone_name=>"BAD").time_zone
      }.to raise_error "Invalid time zone name: BAD"
    end
  end
end
