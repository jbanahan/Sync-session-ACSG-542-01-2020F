require 'spec_helper'

describe SearchSchedule do
  describe "run_search" do
    let(:now) { ActiveSupport::TimeZone["Hawaii"].local(2001,2,3,4,5,6) }
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
      expect(log).to receive(:info).twice

      # Use the block version here so we can also verify that User.current and Time.zone is set to the 
      # search setup's user in the context of the write_csv call
      expect(@ss).to receive(:write_csv) {|setup, tempfile|
        expect(setup).to eq(@setup)
        expect(User.current).to eq(@setup.user)
        expect(Time.zone).to eq(ActiveSupport::TimeZone[@setup.user.time_zone])
      }
      allow(@ss).to receive(:send_email).with(@setup.name, an_instance_of(Tempfile), '-_t_e_s_t_._t_x_t_20010203040506000.csv', @u, log)
      expect(@ss).to receive(:send_ftp).with(@setup.name, an_instance_of(Tempfile), '-_t_e_s_t_._t_x_t_20010203040506000.csv', log)
      
      Timecop.freeze(now) { @ss.run log }
       
      expect(@ss.last_finish_time).not_to be_nil
      
    end

    it "should run with a custom report and no search" do
      @ss.search_setup = nil
      @ss.update_attributes(:download_format => "xls")

      allow(@report).to receive(:user) {@u}
      # We tested a full sanitization earlier, just double check that it's still being done here too
      allow(@report).to receive(:name) {'test/t!st.txt'}

      # Use the block version here so we can also verify that User.current and Time.zone is set to the 
      # custom report's user in the context of the write_csv call
      expect(@report).to receive(:xls_file) {|user|
        expect(user).to eq(@u)
        expect(User.current).to eq(@u)
        expect(Time.zone).to eq(ActiveSupport::TimeZone[@u.time_zone])
        @temp
      }
      
      log = double
      expect(log).to receive(:info).twice

      expect(@ss).to receive(:send_email).with(@report.name, @temp, 't_st.txt_20010203040506000.xls', @u, log)
      expect(@ss).to receive(:send_ftp).with(@report.name, @temp, 't_st.txt_20010203040506000.xls', log)

      Timecop.freeze(now) { @ss.run log }

      expect(@ss.last_finish_time).not_to be_nil

    end

    it "should run custom report with csv format and no search" do
      @ss.search_setup = nil
      @ss.update_attributes(:download_format => "csv")

      allow(@report).to receive(:user) {@u}
      # We tested a full sanitization earlier, just double check that it's still being done here too
      allow(@report).to receive(:name) {'test/t!st.txt'}

      # Use the block version here so we can also verify that User.current and Time.zone is set to the 
      # custom report's user in the context of the write_csv call
      expect(@report).to receive(:csv_file) {|user|
        expect(user).to eq(@u)
        expect(User.current).to eq(@u)
        expect(Time.zone).to eq(ActiveSupport::TimeZone[@u.time_zone])
        @temp
      }
      
      log = double
      expect(log).to receive(:info).twice

      expect(@ss).to receive(:send_email).with(@report.name, @temp, 't_st.txt_20010203040506000.csv', @u, log)
      expect(@ss).to receive(:send_ftp).with(@report.name, @temp, 't_st.txt_20010203040506000.csv', log)

      Timecop.freeze(now) { @ss.run log }

      expect(@ss.last_finish_time).not_to be_nil

    end

    it "should run with a custom report and search setup, excluding timestamp if specified" do
      @ss.exclude_file_timestamp = true
      log = double
      expect(log).to receive(:info).exactly(3).times

      expect(@ss).to receive(:write_csv) { |setup, tempfile|
        expect(setup).to eq(@setup)
        expect(User.current).to eq(@setup.user)
        expect(Time.zone).to eq(ActiveSupport::TimeZone[@setup.user.time_zone])
      }

      allow(@ss).to receive(:send_email).with(@setup.name, an_instance_of(Tempfile), '-_t_e_s_t_._t_x_t.csv', @u, log)
      expect(@ss).to receive(:send_ftp).with(@setup.name, an_instance_of(Tempfile), '-_t_e_s_t_._t_x_t.csv', log)

      allow(@report).to receive(:user) {@u}
      # We tested a full sanitization earlier, just double check that it's still being done here too
      allow(@report).to receive(:name) {'test/t!st.txt'}
      expect(@report).to receive(:csv_file) {|u|
        expect(u).to eq(@u)
        expect(User.current).to eq(@report.user)
        expect(Time.zone).to eq(ActiveSupport::TimeZone[@report.user.time_zone])
        @temp
      }
      
      expect(@ss).to receive(:send_email).with(@report.name, @temp, 't_st.txt.csv', @u, log)
      expect(@ss).to receive(:send_ftp).with(@report.name, @temp, 't_st.txt.csv', log)

      Timecop.freeze(now) { @ss.run log }

      expect(@ss.last_finish_time).not_to be_nil
    end

    context "'send_if_empty' is false" do
      before(:each) { @ss.update_attributes(send_if_empty: false) }
      
      it "does email/ftp user if there are search results" do
        @ss.custom_report = nil
        log = double
        expect(log).to receive(:info).exactly(2).times

        allow(@ss).to receive(:write_csv).and_return true
        
        expect(@ss).to receive(:send_email)
        expect(@ss).to receive(:send_ftp)

        @ss.run log
      end

      it "does email/ftp user if there are custom reports" do
        @ss.search_setup = nil
        allow(@report).to receive(:csv_file).and_return @temp
        log = double
        expect(log).to receive(:info).exactly(2).times

        allow(@ss).to receive(:report_blank?).and_return false
        
        expect(@ss).to receive(:send_email)
        expect(@ss).to receive(:send_ftp)

        @ss.run log
      end

      it "doesn't email/ftp user if there are no search results" do
        @ss.custom_report = nil
        log = double
        expect(log).to receive(:info).exactly(2).times

        allow(@ss).to receive(:write_csv).and_return false
        
        expect(@ss).not_to receive(:send_email)
        expect(@ss).not_to receive(:send_ftp)
        
        @ss.run log
      end

      it "doesn't email/ftp user if there are no custom reports" do
        @ss.search_setup = nil
        allow(@report).to receive(:csv_file).and_return @temp
        log = double
        expect(log).to receive(:info).exactly(2).times

        allow(@ss).to receive(:report_blank?).and_return true
        expect(@ss).not_to receive(:send_email)
        expect(@ss).not_to receive(:send_ftp)
        
        @ss.run log     
      end
    end

    it "sends user messages when search fails" do
      @ss.custom_report = nil
      expect(@ss).to receive(:write_csv).and_raise "Failed"
      log = double("Logger")
      allow(log).to receive(:info)
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
      expect(tf).to receive(:path).and_return "path"
      expect(FtpSender).to receive(:send_file).with("server", "user", "pwd", "path", remote_file_name: "file.txt")
      m = @s.send(:send_ftp, "Setup Name", tf, "file.txt")
      expect(m).to match /: FTP complete/
    end

    it "should send sftp" do
      @s.protocol = 'sftp'

      tf = double("Tempfile")
      expect(tf).to receive(:path).and_return "path"
      expect(FtpSender).to receive(:send_file).with("server", "user", "pwd", "path", remote_file_name: "file.txt", protocol: 'sftp')
      m = @s.send(:send_ftp, "Setup Name", tf, "file.txt")
      expect(m).to match /: SFTP complete/
    end

    it "should send to a subdirectory" do
      @s.ftp_subfolder = "subdir"

      tf = double("Tempfile")
      expect(tf).to receive(:path).and_return "path"
      expect(FtpSender).to receive(:send_file).with("server", "user", "pwd", "path", remote_file_name: "file.txt", folder: 'subdir')
      m = @s.send(:send_ftp, "Setup Name", tf, "file.txt")
      expect(m).to match /: FTP complete/
    end

    it "should not send if server, user, or password is blank" do
      expect(FtpSender).not_to receive(:send_file)
      @s.ftp_server = ""

      expect(@s.send(:send_ftp, "Setup Name", double("Tempfile"), "file.txt")).to be_nil
      @s.ftp_server = "server"
      @s.ftp_username = ""
      expect(@s.send(:send_ftp, "Setup Name", double("Tempfile"), "file.txt")).to be_nil
      @s.ftp_username = "user"
      @s.ftp_password = ""
      expect(@s.send(:send_ftp, "Setup Name", double("Tempfile"), "file.txt")).to be_nil
    end

    context "errors" do
      before :each do
        @u = Factory(:user)
        @setup = SearchSetup.new(:user=>@u, :name=>"Search Setup")
        @s.search_setup = @setup
      end

      it "should send and email and create user message" do
        expect(FtpSender).to receive(:send_file).and_raise IOError, "Error!"
        m = double("mail")
        expect(m).to receive("deliver")
        expect(OpenMailer).to receive(:send_search_fail).with(@u.email, @setup.name, "Error!", @s.ftp_server, @s.ftp_username, @s.ftp_subfolder).and_return m
        tf = double("Tempfile")
        expect(tf).to receive(:path)
        @s.send(:send_ftp, "Setup Name", tf, "file.txt")

        expect(@u.messages.first.subject).to eq "Search Transmission Failure"
        expect(@u.messages.first.body).to eq "Search Name: #{@setup.name}<br>"+
          "Protocol: FTP<br>" +
          "Server Name: #{@s.ftp_server}<br>"+
          "Account: #{@s.ftp_username}<br>"+
          "Subfolder: #{@s.ftp_subfolder}<br>"+
          "Error Message: Error!"
      end
    end
  end

  describe "report_blank?" do
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

  describe "send_email" do
    let!(:sched) { Factory(:search_schedule, email_addresses: "tufnel@stonehenge.biz, st-hubbins@hellhole.co.uk") }
    let!(:user) { sched.search_setup.user }

    context "when addresses are valid" do
      it "sends email to schedule recipients" do
        allow_any_instance_of(OpenMailer).to receive(:blank_attachment?).and_return false
        Tempfile.open(['tempfile', '.txt']) do |file|
          sched.send_email "search name", file, "attachment name", user
          mail = ActionMailer::Base.deliveries.pop
          expect(mail.to).to eq(['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk'])
          expect(mail.subject).to eq('[VFI Track] search name Result')
          expect(mail.attachments.size).to eq 1
        end
      end
      it "logs attempt to send emails if applicable" do
        log = double("log")
        now = Time.now
        Timecop.freeze(now) do
          Tempfile.open(['tempfile', '.txt']) do |file|
            expect(log).to receive(:info).with("#{now}: Attempting to send email to tufnel@stonehenge.biz, st-hubbins@hellhole.co.uk")
            expect(log).to receive(:info).with("#{now}: Sent email")
            sched.send_email "search name", file, "attachment name", user, log
          end
        end
      end
    end
    it "sends email to account owner if any of the schedule addresses are bad" do
      stub_master_setup
      allow_any_instance_of(OpenMailer).to receive(:blank_attachment?).and_return false
      sched.update_attributes(email_addresses: "tufnel@stonehenge.biz, st-hubbinshellhole.co.uk")
      user.update_attributes(email: "smalls@sharksandwich.net")
      Tempfile.open(['tempfile', '.txt']) do |file|
          sched.send_email "search name", file, "attachment name", user
          mail = ActionMailer::Base.deliveries.pop
          expect(mail.to).to eq(['smalls@sharksandwich.net'])
          expect(mail.subject).to eq('[VFI Track] Search Transmission Failure')
          expect(mail.body.raw_source).to include "/advanced_search/#{sched.search_setup.id}"
          expect(mail.body.raw_source).to include "The above scheduled search contains an invalid email address. Please correct it and try again."
          expect(mail.attachments.size).to eq 0
        end
    end
    it "returns immediately if the schedule doesn't have email addresses" do
      allow_any_instance_of(OpenMailer).to receive(:blank_attachment?).and_return false
      sched.update_attributes(email_addresses: nil)
      Tempfile.open(['tempfile', '.txt']) do |file|
        sched.send_email "search name", file, "attachment name", user
        expect(ActionMailer::Base.deliveries.pop).to be_nil
      end
    end
  end

end
