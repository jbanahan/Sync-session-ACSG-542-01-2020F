require 'spec_helper'

describe SearchSchedule do
  describe "run_search" do
    before :each do
      @temp = Tempfile.new ["search_schedule_spec", ".xls"]
      @u = Factory(:user, :time_zone => "Hawaii")
      @setup = SearchSetup.new(:user=>@u, 
        # use a name that needs to be sanitized -> -test.txt
        :name => 'test/-#t!e~s)t .^t&x@t', :download_format => 'csv'
        )
      @report = CustomReport.new(:user => @u, name: "blah")
      @ss = SearchSchedule.new(:search_setup=>@setup, :custom_report=>@report, :download_format=>"csv", :send_if_empty=>true)
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
      @ss.should_receive(:write_csv) {|setup, tempfile|
        setup.should == @setup
        User.current.should == @setup.user
        Time.zone.should == ActiveSupport::TimeZone[@setup.user.time_zone]
      }
      @ss.stub(:send_email).with(@setup.name, an_instance_of(Tempfile), '-_t_e_s_t_._t_x_t.csv', @u, log)
      @ss.should_receive(:send_ftp).with(@setup.name, an_instance_of(Tempfile), '-_t_e_s_t_._t_x_t.csv', log)
      
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

      @ss.should_receive(:send_email).with(@report.name, @temp, 't_st.txt.xls', @u, log)
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

      @ss.should_receive(:send_email).with(@report.name, @temp, 't_st.txt.csv', @u, log)
      @ss.should_receive(:send_ftp).with(@report.name, @temp, 't_st.txt.csv', log)

      @ss.run log

      @ss.last_finish_time.should_not be_nil

    end

    it "should run with a custom report and search setup" do
      log = double
      log.should_receive(:info).exactly(3).times

      @ss.should_receive(:write_csv) { |setup, tempfile|
        setup.should == @setup
        User.current.should == @setup.user
        Time.zone.should == ActiveSupport::TimeZone[@setup.user.time_zone]
      }

      @ss.stub(:send_email).with(@setup.name, an_instance_of(Tempfile), '-_t_e_s_t_._t_x_t.csv', @u, log)
      @ss.should_receive(:send_ftp).with(@setup.name, an_instance_of(Tempfile), '-_t_e_s_t_._t_x_t.csv', log)

      @report.stub(:user) {@u}
      # We tested a full sanitization earlier, just double check that it's still being done here too
      @report.stub(:name) {'test/t!st.txt'}
      @report.should_receive(:csv_file) {|u|
        u.should == @u
        User.current.should == @report.user
        Time.zone.should == ActiveSupport::TimeZone[@report.user.time_zone]
        @temp
      }
      
      @ss.should_receive(:send_email).with(@report.name, @temp, 't_st.txt.csv', @u, log)
      @ss.should_receive(:send_ftp).with(@report.name, @temp, 't_st.txt.csv', log)

      @ss.run log

      @ss.last_finish_time.should_not be_nil
    end

    context "'send_if_empty' is false" do
      before(:each) { @ss.update_attributes(send_if_empty: false) }
      
      it "doesn't email/ftp user if there are no search results" do
        @ss.custom_report = nil
        log = double
        log.should_receive(:info).exactly(2).times
        @ss.should_receive(:write_csv)

        @ss.stub(:report_blank?).and_return true
        @ss.should_not_receive(:send_email)
        @ss.should_not_receive(:send_ftp)
        
        @ss.run log
      end

      it "doesn't email/ftp user if there are no custom reports" do
        @ss.search_setup = nil
        @report.stub(:csv_file).and_return @temp
        log = double
        log.should_receive(:info).exactly(2).times

        @ss.stub(:report_blank?).and_return true
        @ss.should_not_receive(:send_email)
        @ss.should_not_receive(:send_ftp)
        
        @ss.run log     
      end
    end

    it "sends user messages when search fails" do
      @ss.custom_report = nil
      @ss.should_receive(:write_csv).and_raise "Failed"
      log = double("Logger")
      log.stub(:info)
      @ss.run log

      expect(@ss.user.messages.length).to eq 1
      m = @ss.user.messages.first

      expect(m.body).to include "Search Name: #{@setup.name}"
      expect(m.body).to include "Error Message: Failed"
    end

  end

  describe "send_ftp" do
    before :each do
      @s = SearchSchedule.new ftp_server: "server", ftp_username: "user", ftp_password: "pwd"
    end

    it "should send ftp" do
      tf = double("Tempfile")
      tf.should_receive(:path).and_return "path"
      FtpSender.should_receive(:send_file).with("server", "user", "pwd", "path", remote_file_name: "file.txt")
      m = @s.send(:send_ftp, "Setup Name", tf, "file.txt")
      m.should match /: FTP complete/
    end

    it "should send sftp" do
      @s.protocol = 'sftp'

      tf = double("Tempfile")
      tf.should_receive(:path).and_return "path"
      FtpSender.should_receive(:send_file).with("server", "user", "pwd", "path", remote_file_name: "file.txt", protocol: 'sftp')
      m = @s.send(:send_ftp, "Setup Name", tf, "file.txt")
      m.should match /: SFTP complete/
    end

    it "should send to a subdirectory" do
      @s.ftp_subfolder = "subdir"

      tf = double("Tempfile")
      tf.should_receive(:path).and_return "path"
      FtpSender.should_receive(:send_file).with("server", "user", "pwd", "path", remote_file_name: "file.txt", folder: 'subdir')
      m = @s.send(:send_ftp, "Setup Name", tf, "file.txt")
      m.should match /: FTP complete/
    end

    it "should not send if server, user, or password is blank" do
      FtpSender.should_not_receive(:send_file)
      @s.ftp_server = ""

      @s.send(:send_ftp, "Setup Name", double("Tempfile"), "file.txt").should be_nil
      @s.ftp_server = "server"
      @s.ftp_username = ""
      @s.send(:send_ftp, "Setup Name", double("Tempfile"), "file.txt").should be_nil
      @s.ftp_username = "user"
      @s.ftp_password = ""
      @s.send(:send_ftp, "Setup Name", double("Tempfile"), "file.txt").should be_nil
    end

    context :errors do
      before :each do
        @u = Factory(:user)
        @setup = SearchSetup.new(:user=>@u, :name=>"Search Setup")
        @s.search_setup = @setup
      end

      it "should send and email and create user message" do
        FtpSender.should_receive(:send_file).and_raise IOError, "Error!"
        m = double("mail")
        m.should_receive("deliver")
        OpenMailer.should_receive(:send_search_fail).with(@u.email, @setup.name, "Error!", @s.ftp_server, @s.ftp_username, @s.ftp_subfolder).and_return m
        tf = double("Tempfile")
        tf.should_receive(:path)
        @s.send(:send_ftp, "Setup Name", tf, "file.txt")

        @u.messages.first.subject.should eq "Search Transmission Failure"
        @u.messages.first.body.should eq "Search Name: #{@setup.name}<br>"+
          "Protocol: FTP<br>" +
          "Server Name: #{@s.ftp_server}<br>"+
          "Account: #{@s.ftp_username}<br>"+
          "Subfolder: #{@s.ftp_subfolder}<br>"+
          "Error Message: Error!"
      end
    end
  end

  describe :report_blank? do
    before(:each) { @ss = SearchSchedule.new }

    it "returns true when an xls report is blank" do
      File.open("spec/fixtures/files/blank_report_1.xls", "r") do |xls_file|
        expect(@ss.send(:report_blank?, xls_file)).to be true
      end
      File.open("spec/fixtures/files/blank_report_2.xls", "r") do |xls_file|
        expect(@ss.send(:report_blank?, xls_file)).to be true
      end
    end

    it "returns true when a cvs report is blank" do
      File.open("spec/fixtures/files/blank_report_1.csv", "r") do |xls_file|
        expect(@ss.send(:report_blank?, xls_file)).to be true
      end
      File.open("spec/fixtures/files/blank_report_2.csv", "r") do |csv_file|
        expect(@ss.send(:report_blank?, csv_file)).to be true
      end
    end

    it "returns false when an xls report isn't blank" do
      File.open("spec/fixtures/files/test_sheet_1.xls", "r") do |xls_file|
        expect(@ss.send(:report_blank?, xls_file)).to be false
      end
    end

    it "returns false when a csv report isn't blank" do
      File.open("spec/fixtures/files/test_sheet_3.csv", "r") do |csv_file|
        expect(@ss.send(:report_blank?, csv_file)).to be false
      end
    end
  end

end
