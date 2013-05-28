require 'spec_helper'

describe SearchSchedule do
  describe "run_search" do
    before :each do
      @temp = Tempfile.new ["search_schedule_spec", ".xls"]
      @u = User.new :time_zone => "Hawaii"
      @setup = SearchSetup.new(:user=>@u, 
        # use a name that needs to be sanitized -> -test.txt
        :name => 'test/-#t!e~s)t .^t&x@t', :download_format => 'csv'
        )
      @report = CustomReport.new(:user => @u)
      @ss = SearchSchedule.new(:search_setup=>@setup, :custom_report=>@report, :download_format=>"csv")
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
      @ss.update_attributes(:download_format => "xls")

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

    it "should run custom report with csv format and no search" do
      @ss.search_setup = nil
      @ss.update_attributes(:download_format => "csv")

      @report.stub(:user) {@u}
      # We tested a full sanitization earlier, just double check that it's still being done here too
      @report.stub(:name) {'test/t!st.txt'}

      # Use the block version here so we can also verify that User.current and Time.zone is set to the 
      # custom report's user in the context of the write_csv call
      @report.should_receive(:csv_file) {|user|
        user.should == @u
        User.current.should == @u
        Time.zone.should == ActiveSupport::TimeZone[@u.time_zone]
        @temp
      }
      
      log = double
      log.should_receive(:info).twice

      @ss.should_receive(:send_email).with(@report.name, @temp, 't_st.txt.csv', log)
      @ss.should_receive(:send_ftp).with(@report.name, @temp, 't_st.txt.csv', log)

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
      @report.should_receive(:csv_file) {|u|
        u.should == @u
        User.current.should == @report.user
        Time.zone.should == ActiveSupport::TimeZone[@report.user.time_zone]
        @temp
      }
      
      @ss.should_receive(:send_email).with(@report.name, @temp, 't_st.txt.csv', log)
      @ss.should_receive(:send_ftp).with(@report.name, @temp, 't_st.txt.csv', log)

      @ss.run log

      @ss.last_finish_time.should_not be_nil
    end

  end
end
