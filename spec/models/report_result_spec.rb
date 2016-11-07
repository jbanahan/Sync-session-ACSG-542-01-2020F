# encoding: utf-8
require 'spec_helper'

describe ReportResult do
  before :each do
    @u = Factory(:user, :email=>'a@vandegriftinc.com', :time_zone => 'Hawaii')
    allow_any_instance_of(MasterSetup).to receive(:request_host).and_return "localhost"
  end

  describe 'friendly settings' do

    it "should handle friendly settings array" do
      r = ReportResult.new
      r.friendly_settings = ['a','b']
      expect(r.friendly_settings).to eq(['a','b'])
    end

    it "should return empty array when no friendly settings are set" do
      expect(ReportResult.new.friendly_settings).to eq([])
    end 
  end

  describe "security" do
    before :each do 
      @r = ReportResult.new
      @r.run_by = @u
    end
    it "allows sysadmins" do
      sys_admin = User.new
      sys_admin.sys_admin = true
      expect(@r.can_view?(sys_admin)).to be_truthy
    end

    it "allows the same user" do
      expect(@r.can_view?(@u)).to be_truthy
    end

    it "doesn't allow a different user" do
      other_user = User.new
      expect(@r.can_view?(other_user)).to be_falsey
    end
  end

  describe "run report", :disable_delayed_jobs do
    class SampleReport
      cattr_reader :tempfiles

      def self.run_report user, opts
        @@tempfiles ||= []

        tempfile = Tempfile.open(["sample_report", ".txt"])
        tempfile << "mystring"
        tempfile.flush
        tempfile.rewind
        Attachment.add_original_filename_method tempfile, "sample_report.txt"

        @@tempfiles << tempfile

        tempfile
      end
    end

    before :each do
      @report_class = SampleReport
    end
    after :each do
      Array.wrap(SampleReport.tempfiles).each {|t| t.close! unless t.closed? }
      SampleReport.tempfiles.clear if SampleReport.tempfiles
    end
    it "should write data on report run" do
      allow_any_instance_of(ReportResult).to receive(:execute_report)
      ReportResult.run_report! 'nrr', @u, @report_class, {:settings=>{'o1'=>'o2'},:friendly_settings=>['a','b']}
      found = ReportResult.find_by_name('nrr')
      expect(found.run_by).to eq(@u)
      expect(found.report_class).to eq(@report_class.to_s)
      expect(found.run_at).to be > 10.seconds.ago
      expect(found.friendly_settings_json).to eq(['a','b'].to_json)
      expect(found.settings_json).to eq({'o1'=>'o2'}.to_json)
    end
    it "enqueues report before running" do
      allow_any_instance_of(ReportResult).to receive(:execute_report)
      ReportResult.run_report! 'ebr', @u, @report_class
      found = ReportResult.find_by_name('ebr')
      expect(found.status).to eq("Queued")
    end

    it "sets report as Complete when done" do
      ReportResult.run_report! 'fin', @u, @report_class
      found = ReportResult.find_by_name('fin')
      expect(found.status).to eq("Complete")
    end
    it "deletes the underlying file when report is finished" do
      ReportResult.run_report! 'del', @u, @report_class
      expect(SampleReport.tempfiles.length).to eq 1
      expect(SampleReport.tempfiles[0]).to be_closed
    end
    it "attaches report content to ReportResult", paperclip: true, s3: true do
      ReportResult.run_report! 'cont', @u, @report_class
      found = ReportResult.find_by_name 'cont'
      rc = found.report_content
      expect(rc).to eq("mystring")
    end
    it "writes user message when report is finished" do
      ReportResult.run_report! 'msg', @u, @report_class
      found = ReportResult.find_by_name 'msg'
      m = @u.messages
      expect(m.size).to eq(1)
      expect(m.first.body).to include "/report_results/#{found.id}/download" #message body includes download link
    end
    it "delays the report with priority 100" do
      allow_any_instance_of(ReportResult).to receive(:execute_report) #don't need report to run
      expect_any_instance_of(ReportResult).to receive(:delay).with(:priority=>-1).and_return(ReportResult.new)
      ReportResult.run_report! 'delay', @u, @report_class
    end

    it "should run with user settings" do
      expect(SampleReport).to receive(:run_report) do |run_by|
        expect(User.current).to eq(run_by)
        expect(Time.zone).to eq(ActiveSupport::TimeZone[run_by.time_zone])

        loc = 'test/assets/sample_report.txt'
        File.open(loc,'w') {|f| f.write('mystring')}
        File.new loc
      end
      ReportResult.run_report! 'user settings', @u, @report_class
    end

    it "detects alliance reports" do
      class AllianceReport
        def self.alliance_report?
          true
        end

        def self.run_report user, opts
          loc = 'spec/support/tmp/sample_report.txt'
          File.open(loc,'w') {|f| f.write('mystring')}
          File.new loc
        end
      end
      rr = double("ReportResult") 
      expect(rr).to receive(:execute_alliance_report)
      expect_any_instance_of(ReportResult).to receive(:delay).with(priority: -1).and_return(rr)
      ReportResult.run_report! 'delay', @u, AllianceReport
    end

    it "detects non-alliance reports reponding to alliance_report?" do
      class NonAllianceReport
        def self.alliance_report?
          false
        end

        def self.run_report user, opts
          loc = 'spec/support/tmp/sample_report.txt'
          File.open(loc,'w') {|f| f.write('mystring')}
          File.new loc
        end
      end
      rr = double("ReportResult") 
      expect(rr).to receive(:execute_report)
      expect_any_instance_of(ReportResult).to receive(:delay).with(priority: -1).and_return(rr)
      ReportResult.run_report! 'delay', @u, NonAllianceReport
    end

    it "emails file to user if email_to is set" do
       ReportResult.run_report! 'user settings', @u, @report_class, 'email_to' => 'me@there.com'
       expect(ActionMailer::Base.deliveries.length).to eq 1
       m = ActionMailer::Base.deliveries.first
       expect(m.to).to eq ["me@there.com"]
       expect(m.subject).to eq "Report Complete: user settings"
       expect(m.attachments['sample_report.txt']).not_to be_nil
    end

    describe "error handling" do
      
      context "report fails" do
        before(:each) do
          allow(SampleReport).to receive(:run_report).and_raise('some error message')
        end

        it "sets reports that threw exceptions as failed" do
          ReportResult.run_report! 'fail', @u, @report_class
          found = ReportResult.find_by_name 'fail'
          expect(found.status).to eq("Failed")
        end
        it "writes report errors when failing" do
          ReportResult.run_report! 'err msg', @u, @report_class
          found = ReportResult.find_by_name 'err msg'
          expect(found.run_errors).to eq('some error message')
        end
        it "writes a user message containing the word failed in the subject when report fails" do
          ReportResult.run_report! 'um', @u, @report_class
          m = @u.messages
          expect(m.size).to eq(1)
          expect(m.first.subject).to include "FAILED"
          found = ReportResult.find_by_name 'um'
          expect(m.first.body).to include "/report_results/#{found.id}"
        end
      end
      
      context "report handling fails" do
        it "deletes the underlying file when report completion fails" do
          expect_any_instance_of(ReportResult).to receive(:complete_report).and_raise "Error"
          ReportResult.run_report! 'uf', @u, @report_class
          expect(SampleReport.tempfiles.length).to eq 1
          expect(SampleReport.tempfiles[0]).to be_closed
        end
      end
    end
  end

  describe "purge" do
    before(:each) do
      6.times do |i|
        #alternate between making reports that are less than & greater than a week old
        ReportResult.create!(:name=>'rr',:run_at=>(i.modulo(2)==0 ? 8.days.ago : 6.days.ago))
      end
    end
    it "should have an eligible_for_purge scope that returns all reports more than a week old" do
      found = ReportResult.eligible_for_purge
      expect(found.size).to eq(3)
      found.each {|r| expect(r.run_at).to be < 1.week.ago}
    end
    it "should return a purge_at time of 1 week after run_at" do
      report = ReportResult.first
      expect(report.purge_at).to eq(report.run_at+1.week)
    end
    it "should return nil for purge_at with no run_at" do
      expect(ReportResult.new.purge_at).to be_nil
    end
    it "should have a purge that actually reports that are eligible for purge" do
      ReportResult.purge
      found = ReportResult.all
      expect(found.size).to eq(3)
      found.each {|r| expect(r.purge_at).to be > 0.days.ago}
    end
  end

  describe "sanitize callback" do
    it "should sanitize the attached filename" do
      r = ReportResult.new
      r.report_data_file_name = "照片\/:*?\"<>|\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031.jpg"
      r.save
      expect(r.report_data_file_name).to eq("___________________________________.jpg")
    end
  end

  describe "execute_alliance_report" do
    before :each do
      class TestReport; end
      @report_class = TestReport
      @r = ReportResult.create! settings_json: {'settings' => '1'}.to_json, run_by_id: @u.id, status: "new", report_class: @report_class.to_s
    end

    it "runs an alliance report" do
      expect(User).to receive(:run_with_user_settings).and_yield
      settings = ActiveSupport::JSON.decode(@r.settings_json)
      settings["report_result_id"] = @r.id
      expect(@report_class).to receive(:run_report).with(@u, settings)

      @r.execute_alliance_report
      
      @r.reload
      expect(@r.status).to eq "Running"
    end

    it "handles any errors raised while starting report" do
      expect(@report_class).to receive(:run_report).and_raise "Error"

      @r.execute_alliance_report

      expect(@u.messages.size).to eq(1)
      @r.reload
      expect(@r.status).to eq "Failed"
    end
  end

  describe "continue_alliance_report" do
    before :each do
      class TestReport; end
      @report_class = TestReport
      @r = ReportResult.create! settings_json: {'settings' => '1'}.to_json, run_by_id: @u.id, status: "new", report_class: @report_class.to_s
      @tf = Tempfile.new "ContinueAlliancReportSpec"
      @tf << "Testing"
    end

    after :each do
      @tf.close! unless @tf.closed?
    end

    it "continues an alliance report" do
      expect(User).to receive(:run_with_user_settings).and_yield
      settings = ActiveSupport::JSON.decode(@r.settings_json)
      results = []
      expect(@report_class).to receive(:process_alliance_query_details).with(@u, results, settings).and_return @tf

      @r.continue_alliance_report results

      @r.reload
      expect(@u.messages.size).to eq(1)
      expect(@r.status).to eq "Complete"
      expect(@r.report_data).to_not be_nil
    end

    it "continues an alliance report with json results" do
      expect(User).to receive(:run_with_user_settings).and_yield
      settings = ActiveSupport::JSON.decode(@r.settings_json)
      results = []
      expect(@report_class).to receive(:process_alliance_query_details).with(@u, results, settings).and_return @tf

      @r.continue_alliance_report results.to_json

      @r.reload
      expect(@u.messages.size).to eq(1)
      expect(@r.status).to eq "Complete"
      expect(@r.report_data).to_not be_nil
    end

    it "handles errors / cleanup if alliance report continuation fails" do
      settings = ActiveSupport::JSON.decode(@r.settings_json)
      results = []
      expect(@report_class).to receive(:process_alliance_query_details).with(@u, results, settings).and_return @tf
      expect(@r).to receive(:complete_report).with(@tf).and_raise "Error"
      @r.continue_alliance_report results

      expect(@u.messages.size).to eq(1)
      @r.reload
      expect(@r.status).to eq "Failed"
      expect(@tf.closed?).to be_truthy
    end
  end

  describe "file_cleanup" do
    it "handles Tempfile" do
      tf = Tempfile.new "file"
      begin
        ReportResult.new.file_cleanup tf
        expect(tf.path).to be_nil
        expect(tf.closed?).to be_truthy
      ensure
        tf.close!
      end
    end

    it "handles File" do
      f = File.new "tmp/file", "w"
      begin
        ReportResult.new.file_cleanup f
        expect(f.closed?).to be_truthy
        expect(File.exists?(f.path)).to be_falsey
      ensure
        File.delete(f) if File.exists?(f.path)
      end
    end

    it "handles String" do
      f = File.new "tmp/file", "w"
      begin
        ReportResult.new.file_cleanup f.path
        expect(File.exists?(f.path)).to be_falsey
      ensure
        File.delete(f) if File.exists?(f.path)
      end
    end

    it "handles nil" do
      ReportResult.new.file_cleanup nil
    end
  end

  describe "run_schedulable" do
    it "implements SchedulableJob interface" do
      expect(ReportResult).to receive(:purge)
      ReportResult.run_schedulable
    end
  end
end
