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
  end

  describe :time_zone do
    it "should default to eastern" do
      SchedulableJob.new.time_zone.should == ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    end
    it "should override" do
      SchedulableJob.new(:time_zone_name=>"American Samoa").time_zone.should == ActiveSupport::TimeZone["American Samoa"] #Tony Rocky Horror
    end
  end
end
