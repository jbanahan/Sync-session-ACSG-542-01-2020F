require 'spec_helper'

describe OpenChain::ScheduleSupport do
  describe "run_if_needed" do
    before :each do
      @ss = Factory(:search_schedule,:last_start_time=>1.year.ago) 
    end
    it "should run if next_run_time < Time.now.utc" do
      @ss.stub(:next_run_time).and_return 1.year.ago
      @ss.should_receive(:run).and_return true
      @ss.run_if_needed
    end
    it "should set last_run time" do
      @ss.stub(:next_run_time).and_return 1.year.ago
      @ss.should_receive(:run).and_return true
      @ss.run_if_needed
      SearchSchedule.find(@ss.id).last_start_time.should > 5.seconds.ago
    end
    it "should not run if next_run_time > Time.now.utc" do
      @ss.stub(:next_run_time).and_return 1.year.from_now
      @ss.should_not_receive(:run)
      @ss.run_if_needed
    end

    it "tracks run status of schedulable jobs" do
      sj = SchedulableJob.create! run_class: "OpenChain::StatClient", last_start_time: 1.year.ago, run_interval: "* * * * *"
      Lock.should_receive(:acquire).with("ScheduleSupport-SchedulableJob-#{sj.id}", times: 3, temp_lock: true).and_yield
      sj.should_receive(:run) do |log|
        expect(sj.running).to be_true
      end
      expect(sj.run_if_needed).to be_true
    end

    it "does not run if another job is already running and concurrency is disabled" do
      last_start = 1.year.ago
      sj = SchedulableJob.create! run_class: "OpenChain::StatClient", last_start_time: last_start, run_interval: "* * * * *", running: true, no_concurrent_jobs: true
      sj.should_not_receive(:run)
      sj.reload
      expect(sj.run_if_needed).to be_false
      expect(sj.running).to be_true
      expect(sj.last_start_time.to_i).to eq last_start.to_i
    end

    it "runs if another job is already running and concurrency is allowed" do
      last_start = 1.year.ago
      sj = SchedulableJob.create! run_class: "OpenChain::StatClient", last_start_time: last_start, run_interval: "* * * * *", running: true
      sj.should_receive(:run)
      expect(sj.run_if_needed).to be_true
    end
  end

  describe "needs_to_run?" do
    before :each do
      @ss = Factory(:search_schedule,:last_start_time=>1.year.ago) 
    end

    it "needs to run if next run time before now" do
      @ss.stub(:next_run_time).and_return 1.hour.ago.utc
      expect(@ss.needs_to_run?).to be_true
    end

    it "does not need to run if next runtime is in the future" do
      @ss.stub(:next_run_time).and_return 1.hour.from_now.utc
      expect(@ss.needs_to_run?).to be_false
    end
  end

  describe "next_run_time" do
    before :each do
      @u = User.new
      @ss = SearchSchedule.new(:search_setup=>SearchSetup.new(:user=>@u),:run_monday=>true,
        :run_tuesday=>true,:run_wednesday=>true,:run_thursday=>true,:run_friday=>true,
        :run_saturday=>true,:run_sunday=>true,
        :last_start_time=>1.year.ago)
    end
    it "should identify next run time with EST time zone" do
      tz_str = "Eastern Time (US & Canada)"
      @u.time_zone = tz_str
      @ss.last_start_time = Time.now
      @ss.run_hour = Time.now.in_time_zone(tz_str).hour+1
      now = Time.now.utc
      @ss.next_run_time.should == Time.utc(now.year,now.month,now.day,now.hour+1)
    end
    it "should identify next run time with CST time zone" do
      tz_str = "Central Time (US & Canada)"
      @u.time_zone = tz_str
      @ss.last_start_time = Time.now
      @ss.run_hour = Time.now.in_time_zone(tz_str).hour+1
      now = Time.now.utc
      @ss.next_run_time.should == Time.utc(now.year,now.month,now.day,now.hour+1)
    end
    it "should default to EST if user doesn't have time zone set" do
      tz_str = "Eastern Time (US & Canada)"
      @ss.last_start_time = Time.now
      @ss.run_hour = Time.now.in_time_zone(tz_str).hour+1
      now = Time.now.utc
      @ss.next_run_time.should == Time.utc(now.year,now.month,now.day,now.hour+1)
    end
    it "should skip today's run if today isn't a run day" do
      tz_str = "Eastern Time (US & Canada)"
      @ss.last_start_time = Time.now
      @ss.run_hour = Time.now.in_time_zone(tz_str).hour+1
      now = Time.now.utc
      case now.wday
      when 0
        @ss.run_sunday = false
      when 1
        @ss.run_monday = false
      when 2
        @ss.run_tuesday = false
      when 3
        @ss.run_wednesday = false
      when 4
        @ss.run_thursday = false
      when 5
        @ss.run_friday = false
      when 6
        @ss.run_saturday = false
      end
      @ss.next_run_time.should == Time.utc(now.year,now.month,now.day+(now.day!=Time.now.in_time_zone(tz_str).day ? -1 : 0),now.hour+1)+1.day
    end
    it "should use created_at if last_started_at is nil" do
      tz_str = "Eastern Time (US & Canada)"
      @ss.run_hour = Time.now.in_time_zone(tz_str).hour+1
      @ss.created_at = Time.now 
      @ss.last_start_time = nil
      now = Time.now.utc
      @ss.next_run_time.should == Time.utc(now.year,now.month,now.day,now.hour+1)
    end
    it "should return nil if none of the run days or day of month are set"do
      @ss = SearchSchedule.new(:search_setup=>SearchSetup.new(:user=>@u),:last_start_time=>1.year.ago,:run_hour => 23)
      expect(@ss.next_run_time).to be_nil
    end
    it "should return nil if run hour is not set" do
      tz_str = "Eastern Time (US & Canada)"
      @ss.run_hour = nil
      expect(@ss.next_run_time).to be_nil
    end
    it "should identify next_run_time with minute_to_run set " do
      tz_str = "Eastern Time (US & Canada)"
      @u.time_zone = tz_str
      @ss.last_start_time = Time.now
      @ss.run_hour = Time.now.in_time_zone(tz_str).hour+1
      @ss.stub(:minute_to_run).and_return(30)
      now = Time.now.utc
      @ss.next_run_time.should == Time.utc(now.year,now.month,now.day,now.hour,30) + 1.hour
    end
=begin
    context "day of month" do
      it "should return future if day of month is set to future" do
        tz_str = "Eastern Time (US & Canada)"
        now = Time.now.in_time_zone(tz_str)
        target_hour = now.hour + 1
        target_day = (now + 1.week).day
        @ss = SearchSchedule.new(:search_setup=>SearchSetup.new(:user=>@u),:last_start_time=>1.second.ago)
        @ss.day_of_month = target_day
        @ss.run_hour = target_hour
        @ss.next_run_time.hour.should == now.utc.hour + 1
        @ss.next_run_time.in_time_zone(tz_str).day.should == target_day
        @ss.next_run_time.should > Time.now 
      end
    end
=end
  end

  describe "next_run_time" do
    before :each do 
      c = class FakeSchedulable 
        include OpenChain::ScheduleSupport
      end

      @s = c.new
      @last_start = ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse("2014-01-01")
      @s.stub(:last_start_time).and_return @last_start
    end

    it "uses interval string to determine next runtime" do
      @s.stub(:interval).and_return "1m"
      @s.stub(:wednesday_active?).and_return true

      expect(@s.next_run_time).to eq (@last_start + 1.minute).utc
    end

    it "handles interval hours" do
      @s.stub(:interval).and_return "1h"
      @s.stub(:wednesday_active?).and_return true

      expect(@s.next_run_time).to eq (@last_start + 1.hour)
    end

    it "handles mixed intervals" do
      @s.stub(:interval).and_return "1h30m"
      @s.stub(:wednesday_active?).and_return true

      expect(@s.next_run_time).to eq (@last_start + 1.hour + 30.minutes)
    end

    it "does not run on days that are not configured in the schedule" do
      # Jan 1, 2014 was a wednesday, so the next run time should 
      # be Jan 2 (thurs), midnight
      @s.stub(:interval).and_return "1h"
      @s.stub(:thursday_active?).and_return true

      expect(@s.next_run_time).to eq ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse("2014-01-02").utc
    end

    it "returns nil if no day is configured to run on" do
      @s.stub(:interval).and_return "1h"
      expect(@s.next_run_time).to be_nil
    end

    it "uses interval string as a cron expression (using 1 minute granularity)" do
      @s.stub(:interval).and_return "* * * * *"
      expect(@s.next_run_time).to eq (@last_start + 1.minute).utc
    end

    it "uses cron ranges" do
      @s.stub(:interval).and_return "30-59 * * * *"
      expect(@s.next_run_time).to eq ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse("2014-01-01 00:30").utc
    end

    it "uses cron slash intervals " do
      @s.stub(:interval).and_return "30-59/15 * * * *"
      @last_start = ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse("2014-01-01 00:31")
      @s.stub(:last_start_time).and_return @last_start
      expect(@s.next_run_time).to eq ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse("2014-01-01 00:45").utc
    end

    it "uses cron named weekday ranges" do
      @s.stub(:interval).and_return "0 0 * * THU-FRI"
      expect(@s.next_run_time).to eq ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse("2014-01-02 00:00").utc
    end

    it "uses comma seperated values for cron ranges" do
      @s.stub(:interval).and_return "5,10,15,20 0 * * *"
      expect(@s.next_run_time).to eq (@last_start + 5.minutes).utc
    end

    it "allows for last day of month cron usage" do
      @s.stub(:interval).and_return '0 0 * * FRI#L'
      expect(@s.next_run_time).to eq ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse("2014-01-31 00:00").utc
    end

    it "allows for X-weekday of month cron usage" do
      @s.stub(:interval).and_return '0 0 * * FRI#3'
      expect(@s.next_run_time).to eq ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse("2014-01-17 00:00").utc
    end

    it "allows for second to last weekday of month cron usage" do
      @s.stub(:interval).and_return '0 0 * * FRI#-2'
      expect(@s.next_run_time).to eq ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse("2014-01-24 00:00").utc
    end

    it "handles invalid expressions" do
      @s.stub(:interval).and_return "* * * * * * * *"
      expect(@s.next_run_time).to be_nil
    end
  end
end
