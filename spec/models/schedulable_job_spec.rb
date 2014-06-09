require 'spec_helper'

describe SchedulableJob do
  describe "run" do
    class TestSchedulable
    end
    it "should submit job" do
      TestSchedulable.should_receive(:run_schedulable).with({})
      sj = SchedulableJob.new(:run_class=>"TestSchedulable")
      sj.run
    end
    it "should submit options" do
      opts = {:a=>"b"}.to_json
      TestSchedulable.should_receive(:run_schedulable).with('a'=>'b')
      sj = SchedulableJob.new(:run_class=>"TestSchedulable",:opts=>opts)
      sj.run
    end
    it "should email when successful" do
      opts = {:a=>"b"}.to_json
      TestSchedulable.should_receive(:run_schedulable).with('a'=>'b')
      sj = SchedulableJob.new(:run_class=>"TestSchedulable",:opts=>opts, success_email: "success@email.com")
      sj.run

      m = OpenMailer.deliveries.pop
      m.to.first.should == "success@email.com"
      m.subject.should == "[VFI Track] Scheduled Job Succeeded"
    end
    it "should email when unsuccessful" do
      opts = {:a=>"b"}.to_json
      TestSchedulable.stub(:run_schedulable).and_raise(NameError)
      sj = SchedulableJob.new(:run_class=>"TestSchedulable",:opts=>opts, failure_email: "failure@email.com")

      sj.run

      m = OpenMailer.deliveries.pop
      m.to.first.should == "failure@email.com"
      m.subject.should == "[VFI Track] Scheduled Job Failed"
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
