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
      TestSchedulable.should_receive(:run_schedulable).with({'last_start_time'=>nil})
      sj = SchedulableJob.new(:run_class=>"TestSchedulable")
      sj.run
    end
    it "should submit options" do
      opts = {:a=>"b"}.to_json
      TestSchedulable.should_receive(:run_schedulable).with('last_start_time'=>nil,'a'=>'b')
      sj = SchedulableJob.new(:run_class=>"TestSchedulable",:opts=>opts)
      sj.run
    end
    it "should email when successful" do
      opts = {:a=>"b"}.to_json
      TestSchedulable.should_receive(:run_schedulable).with("last_start_time"=>nil,'a'=>'b')
      sj = SchedulableJob.new(:run_class=>"TestSchedulable",:opts=>opts, success_email: "success1@email.com,success2@email.com")
      sj.run

      m = OpenMailer.deliveries.pop
      m.to.first.should == "success1@email.com"
      m.to.last.should == "success2@email.com"
      m.subject.should == "[VFI Track] Scheduled Job Succeeded"
    end
    it "should email when unsuccessful" do
      opts = {:a=>"b"}.to_json
      TestSchedulable.stub(:run_schedulable).and_raise(NameError)
      sj = SchedulableJob.new(:run_class=>"TestSchedulable",:opts=>opts, failure_email: "failure1@email.com,failure2@email.com")

      sj.run

      m = OpenMailer.deliveries.pop
      m.to.first.should == "failure1@email.com"
      m.to.last.should == "failure2@email.com"
      m.subject.should == "[VFI Track] Scheduled Job Failed"
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
      TestSchedulable.stub(:run_schedulable).and_raise(e)

      e.should_receive(:log_me).with ["Scheduled job for TestSchedulable with options #{opts} has failed"]

      sj = SchedulableJob.new(:run_class=>"TestSchedulable",:opts=>opts.to_json)
      sj.run
    end
  end

  describe :time_zone do
    it "should default to eastern" do
      SchedulableJob.new.time_zone.should == ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    end
    it "should override" do
      SchedulableJob.new(:time_zone_name=>"American Samoa").time_zone.should == ActiveSupport::TimeZone["American Samoa"] #Tony Rocky Horror
    end
    it "should fail on bad tz" do
      lambda {
        SchedulableJob.new(:time_zone_name=>"BAD").time_zone
      }.should raise_error "Invalid time zone name: BAD"
    end
  end
end
