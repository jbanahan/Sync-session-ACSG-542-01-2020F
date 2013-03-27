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
    it "should return a time in the future if none of the run days or day of month are set"do
      @ss = SearchSchedule.new(:search_setup=>SearchSetup.new(:user=>@u),:last_start_time=>1.year.ago,:run_hour => 23)
      @ss.next_run_time.should > Time.now
    end
    it "should return a time in the future if run hour is not set" do
      tz_str = "Eastern Time (US & Canada)"
      @ss.run_hour = nil
      @ss.next_run_time.should > Time.now
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
  describe "run_search" do
    before :each do
      @temp = Tempfile.new ["search_schedule_spec", ".xls"]
      @u = User.new :time_zone => "Hawaii"
      @setup = SearchSetup.new(:user=>@u, 
        # use a name that needs to be sanitized -> -test.txt
        :name => 'test/-#t!e~s)t .^t&x@t', :download_format => 'csv'
        )
      @report = CustomReport.new(:user => @u)
      @ss = SearchSchedule.new(:search_setup=>@setup, :custom_report=>@report)
      @ss.custom_report = @report
    end

    after :each do
      @temp.close!
    end

    it "should run with a search setup and no custom report" do
      # The following methods should be tested individually in another unit test
      # All we care about here is that they're called in the run_search method
      @ss.custom_report = nil
      
      log = double
      log.should_receive(:info).twice

      # Use the block version here so we can also verify that User.current and Time.zone is set to the 
      # search setup's user in the context of the write_csv call
      @ss.should_receive(:write_csv) {|setup|
        setup.should == @setup
        User.current.should == @setup.user
        Time.zone.should == ActiveSupport::TimeZone[@setup.user.time_zone]
        @temp
      }
      @ss.stub(:send_email).with(@setup.name, @temp, '-_t_e_s_t_._t_x_t.csv', log)
      @ss.should_receive(:send_ftp).with(@setup.name, @temp, '-_t_e_s_t_._t_x_t.csv', log)
      
      @ss.run log 

      @ss.last_finish_time.should_not be_nil
      
    end

    it "should run with a custom report and no search" do
      @ss.search_setup = nil

      @report.stub(:user) {@u}
      # We tested a full sanitization earlier, just double check that it's still being done here too
      @report.stub(:name) {'test/t!st.txt'}

      # Use the block version here so we can also verify that User.current and Time.zone is set to the 
      # custom report's user in the context of the write_csv call
      @report.should_receive(:xls_file) {|user|
        user.should == @u
        User.current.should == @u
        Time.zone.should == ActiveSupport::TimeZone[@u.time_zone]
        @temp
      }
      
      log = double
      log.should_receive(:info).twice

      @ss.should_receive(:send_email).with(@report.name, @temp, 't_st.txt.xls', log)
      @ss.should_receive(:send_ftp).with(@report.name, @temp, 't_st.txt.xls', log)

      @ss.run log

      @ss.last_finish_time.should_not be_nil

    end

    it "should run with a custom report and search setup" do
      log = double
      log.should_receive(:info).exactly(3).times

      @ss.should_receive(:write_csv) { |setup|
        setup.should == @setup
        User.current.should == @setup.user
        Time.zone.should == ActiveSupport::TimeZone[@setup.user.time_zone]
        @temp
      }

      @ss.stub(:send_email).with(@setup.name, @temp, '-_t_e_s_t_._t_x_t.csv', log)
      @ss.should_receive(:send_ftp).with(@setup.name, @temp, '-_t_e_s_t_._t_x_t.csv', log)

      @report.stub(:user) {@u}
      # We tested a full sanitization earlier, just double check that it's still being done here too
      @report.stub(:name) {'test/t!st.txt'}
      @report.should_receive(:xls_file) {|u|
        u.should == @u
        User.current.should == @report.user
        Time.zone.should == ActiveSupport::TimeZone[@report.user.time_zone]
        @temp
      }
      
      @ss.should_receive(:send_email).with(@report.name, @temp, 't_st.txt.xls', log)
      @ss.should_receive(:send_ftp).with(@report.name, @temp, 't_st.txt.xls', log)

      @ss.run log

      @ss.last_finish_time.should_not be_nil
    end

  end
end
