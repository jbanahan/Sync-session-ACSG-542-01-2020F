require 'spec_helper'

describe SearchSchedule do
  
  describe "run_search" do

    let(:now) { ActiveSupport::TimeZone["Hawaii"].local(2001,2,3,4,5,6) }
    let(:user) { Factory(:user, time_zone: "Hawaii", email: "tufnel@stonehenge.biz") }
    let(:search_setup) { 
      # use a name that needs to be sanitized -> -test.txt    
      SearchSetup.new module_type: "Product", user: user, name: 'test/-#t!e~s)t .^t&x@t'
    }
    let(:report) { CustomReport.new user: user, name: "test/t!st.txt"}
    let(:search_schedule) { SearchSchedule.new(search_setup: search_setup, custom_report: report, download_format: "csv", send_if_empty: true) }
    let(:tempfile) { Tempfile.new ["search_schedule_spec", ".xls"] }

    after :each do
      tempfile.close! unless tempfile.closed?
    end

    context "with search schedule" do
      before :each do 
        search_schedule.custom_report = nil
      end

      subject { search_schedule }

      it "runs a search as csv and no custom report" do
        expect(User).to receive(:run_with_user_settings).with(user).and_call_original

        # Use the block version here so we can also verify that User.current and Time.zone is set to the 
        # search setup's user in the context of the write_csv call
        expect_any_instance_of(SearchWriter).to receive(:write_search) do |search_writer, tempfile|
          expect(search_writer.output_format).to eq "csv"
          expect(search_writer.search_setup).to eq search_setup
          expect(tempfile).to be_a(Tempfile)

          1
        end

        expect(subject).to receive(:send_email).with(search_setup.name, instance_of(Tempfile), '-_t_e_s_t_._t_x_t_20010203040506000.csv', user)
        expect(subject).to receive(:send_ftp).with(search_setup.name, instance_of(Tempfile), '-_t_e_s_t_._t_x_t_20010203040506000.csv')
        
        Timecop.freeze(now) { subject.run }
         
        expect(subject.last_finish_time).to eq now
        expect(subject.report_failure_count).to eq 0
      end

      it "runs a search as xls and no custom report" do
        subject.download_format = "xls"

        expect_any_instance_of(SearchWriter).to receive(:write_search) do |search_writer, tempfile|
          expect(search_writer.output_format).to eq "xls"
          1
        end

        expect(subject).to receive(:send_email).with(search_setup.name, instance_of(Tempfile), '-_t_e_s_t_._t_x_t_20010203040506000.xls', user)
        expect(subject).to receive(:send_ftp).with(search_setup.name, instance_of(Tempfile), '-_t_e_s_t_._t_x_t_20010203040506000.xls')
        
        Timecop.freeze(now) { subject.run }
      end

      it "runs a search as xlsx and no custom report" do
        subject.download_format = "xlsx"

        expect_any_instance_of(SearchWriter).to receive(:write_search) do |search_writer, tempfile|
          expect(search_writer.output_format).to eq "xlsx"
          1
        end

        expect(subject).to receive(:send_email).with(search_setup.name, instance_of(Tempfile), '-_t_e_s_t_._t_x_t_20010203040506000.xlsx', user)
        expect(subject).to receive(:send_ftp).with(search_setup.name, instance_of(Tempfile), '-_t_e_s_t_._t_x_t_20010203040506000.xlsx')
        
        Timecop.freeze(now) { subject.run }
      end

      it "excludes file timestamp on sent file if specified" do
        subject.exclude_file_timestamp = true
        expect_any_instance_of(SearchWriter).to receive(:write_search).and_return 1
        expect(subject).to receive(:send_email).with(search_setup.name, instance_of(Tempfile), '-_t_e_s_t_._t_x_t.csv', user)
        expect(subject).to receive(:send_ftp).with(search_setup.name, instance_of(Tempfile), '-_t_e_s_t_._t_x_t.csv')
        
        Timecop.freeze(now) { subject.run }
      end

      it "handles max results error" do
        expect_any_instance_of(SearchWriter).to receive(:write_search).and_raise SearchExceedsMaxResultsError
        
        expect(subject).to receive(:send_excessive_size_failure_email).with(user, false)

        subject.run

        expect(subject.report_failure_count).to eq 1
        expect(subject.last_finish_time).to be_nil
        expect(subject.disabled?).to eq false
      end

      it "handles max results error failing more than 5 times" do
        subject.report_failure_count = 4
        expect_any_instance_of(SearchWriter).to receive(:write_search).and_raise SearchExceedsMaxResultsError
        
        expect(subject).to receive(:send_excessive_size_failure_email).with(user, true)

        subject.run

        expect(subject.report_failure_count).to eq 5
        expect(subject.last_finish_time).to be_nil
        expect(subject.disabled?).to eq true
      end

      it "log and emails unexpected errors to the user" do
        error = StandardError.new "Testing"
        expect_any_instance_of(SearchWriter).to receive(:write_search).and_raise error

        expect(error).to receive(:log_me)
        expect(subject).to receive(:send_error_to_user).with user, "Testing"
                
        subject.run
      end

      it "suppresses send if no results are generated" do
        subject.send_if_empty = false
        expect_any_instance_of(SearchWriter).to receive(:write_search).and_return 0
        expect(subject).not_to receive(:send_email)
        expect(subject).not_to receive(:send_ftp)

        subject.run
      end

      it "sends blank file if instructed" do 
        subject.send_if_empty = true

        expect_any_instance_of(SearchWriter).to receive(:write_search).and_return 0
        expect(subject).to receive(:send_email)
        expect(subject).to receive(:send_ftp)

        subject.run
      end
    end

    context "with custom report" do
      before :each do 
        search_schedule.search_setup = nil
      end

      subject { search_schedule }

      it "runs a custom report with xls format and no search" do
        search_schedule.download_format = "xls"

        expect(User).to receive(:run_with_user_settings).with(user).and_call_original
        expect(report).to receive(:xls_file).with(user).and_return tempfile

        expect(subject).to receive(:send_email).with(report.name, tempfile, 't_st.txt_20010203040506000.xls', user)
        expect(subject).to receive(:send_ftp).with(report.name, tempfile, 't_st.txt_20010203040506000.xls')

        Timecop.freeze(now) { subject.run }

        expect(search_schedule.last_finish_time).to eq now
        expect(subject.report_failure_count).to eq 0

      end

      it "runs a custom report with csv format and no search" do
        search_schedule.download_format = "csv"

        expect(report).to receive(:csv_file).with(user).and_return tempfile

        expect(subject).to receive(:send_email).with(report.name, tempfile, 't_st.txt_20010203040506000.csv', user)
        expect(subject).to receive(:send_ftp).with(report.name, tempfile, 't_st.txt_20010203040506000.csv')

        Timecop.freeze(now) { subject.run }

        expect(search_schedule.last_finish_time).to eq now
        expect(subject.report_failure_count).to eq 0
        expect(tempfile.closed?).to eq true
      end

      it "suppresses report if there are no results and send empty is false" do
        search_schedule.send_if_empty = false
        search_schedule.download_format = "csv"

        expect(report).to receive(:csv_file).with(user).and_return tempfile
        expect(subject).to receive(:report_blank?).with(tempfile).and_return true
        expect(subject).not_to receive(:send_email)
        expect(subject).not_to receive(:send_ftp)

        subject.run
      end


      it "sends an empty report if instructed" do
        search_schedule.send_if_empty = true

        expect(report).to receive(:csv_file).with(user).and_return tempfile
        expect(subject).to receive(:send_email)
        expect(subject).to receive(:send_ftp)

        subject.run
      end
    end
  end

  describe "send_ftp" do
    before :each do
      @s = SearchSchedule.new ftp_server: "server", ftp_username: "user", ftp_password: "pwd"
    end

    it "should send ftp" do
      tf = double("Tempfile")
      expect(tf).to receive(:path).and_return "path"
      expect(FtpSender).to receive(:send_file).with("server", "user", "pwd", "path", remote_file_name: "file.txt", port: nil)
      m = @s.send(:send_ftp, "Setup Name", tf, "file.txt")
      expect(m).to match /: FTP complete/
    end

    it "should send sftp" do
      @s.protocol = 'sftp'

      tf = double("Tempfile")
      expect(tf).to receive(:path).and_return "path"
      expect(FtpSender).to receive(:send_file).with("server", "user", "pwd", "path", remote_file_name: "file.txt", protocol: 'sftp', port: nil)
      m = @s.send(:send_ftp, "Setup Name", tf, "file.txt")
      expect(m).to match /: SFTP complete/
    end

    it "should send to a subdirectory" do
      @s.ftp_subfolder = "subdir"

      tf = double("Tempfile")
      expect(tf).to receive(:path).and_return "path"
      expect(FtpSender).to receive(:send_file).with("server", "user", "pwd", "path", remote_file_name: "file.txt", folder: 'subdir', port: nil)
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
    let!(:mailing_list) { Factory(:mailing_list, name: 'blah', user: user, email_addresses: 'mailinglist@domain.com')}

    context "when addresses are valid" do
      it "handles sending to mailing lists" do
        sched.mailing_list = mailing_list
        sched.save!
        sched.reload
        allow_any_instance_of(OpenMailer).to receive(:blank_attachment?).and_return false
        Tempfile.open(['tempfile', '.txt']) do |file|
          sched.send_email "search name", file, "attachment name", user
          mail = ActionMailer::Base.deliveries.pop
          expect(mail.to).to eq(['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk', 'mailinglist@domain.com'])
          expect(mail.subject).to eq('[VFI Track] search name Result')
        end
      end
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

  describe "report_name" do
    subject { described_class }

    let (:search_setup) { SearchSetup.new name: "search"}

    it "generates a report name" do
      expect(subject.report_name(search_setup, "xls")).to eq "search.xls"
    end

    it "generates a timestamp into filename" do
      now = Time.zone.now
      Timecop.freeze(now) do 
        expect(subject.report_name(search_setup, "xls", include_timestamp: true)).to eq "search_#{now.strftime "%Y%m%d%H%M%S%L"}.xls"
      end
      
    end
  end

  describe "stopped?" do
    before :each do
      @u = Factory(:user)
      @setup = SearchSetup.new(:user=>@u)
      @report = CustomReport.new(:user => @u, name: "blah")
      @ss = SearchSchedule.new(:search_setup=>@setup, :custom_report=>@report)
    end

    it "returns false for an enabled search with an active user" do
      @ss.custom_report = nil
      @ss.disabled = false
      @u.disabled = false

      expect(@ss.stopped?).to eq(false)
    end

    it "returns false for an enabled custom report with an active user" do
      @ss.search_setup = nil
      @ss.disabled = false
      @u.disabled = false

      expect(@ss.stopped?).to eq(false)
    end

    it "returns true for a disabled search" do
      @ss.custom_report = nil
      @ss.disabled = true

      expect(@ss.stopped?).to eq(true)
    end

    it "returns true for a disabled custom report" do
      @ss.search_setup = nil
      @ss.disabled = true

      expect(@ss.stopped?).to eq(true)
    end

    it "returns true for a search with an inactive (disabled) user" do
      @ss.custom_report = nil
      @u.disabled = true

      expect(@ss.stopped?).to eq(true)
    end

    it "returns true for a custom report with an inactive (disabled) user" do
      @ss.search_setup = nil
      @u.disabled = true

      expect(@ss.stopped?).to eq(true)
    end
  end

end
