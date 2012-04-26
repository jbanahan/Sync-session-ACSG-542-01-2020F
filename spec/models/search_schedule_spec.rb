require 'spec_helper'

describe SearchSchedule do
  describe "run_if_needed" do
    before :each do
      @ss = Factory(:search_schedule,:last_start_time=>1.year.ago) 
    end
    it "should run if last_run_time in DB matches object's last_run_time and next_run_time < Time.now.utc" do
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
    it "should not run if last_start_time in DB != object's last_run_time" do
      SearchSchedule.update_all(["last_start_time = ?",1.second.ago]) #simulate another thread running the job
      @ss.stub(:next_run_time).and_return 1.year.ago
      @ss.should_not_receive(:run)
      @ss.run_if_needed
    end
  end
  describe "next_run_time" do
    #these tests will fail after 11pm local time... trying to figure out how to fix that without getting too crazy
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
    it "should return a time in the future if none of the run days are set"do
      @ss = SearchSchedule.new(:search_setup=>SearchSetup.new(:user=>@u),:last_start_time=>1.year.ago,:run_hour => 23)
      @ss.next_run_time.should > Time.now
    end
    it "should return a time in the future if run hour is not set" do
      tz_str = "Eastern Time (US & Canada)"
      @ss.run_hour = nil
      @ss.next_run_time.should > Time.now
    end
  end
end
