# encoding: utf-8
require 'spec_helper'

describe ReportResult do
  before :each do
    @u = User.create!(:company_id=>Company.create!(:name=>'x').id,:username=>'user1',:password=>'pass123',:password_confirmation=>'pass123',:email=>'a@aspect9.com', :time_zone => 'Hawaii')
  end

  describe 'friendly settings' do

    it "should handle friendly settings array" do
      r = ReportResult.new
      r.friendly_settings = ['a','b']
      r.friendly_settings.should == ['a','b']
    end

    it "should return empty array when no friendly settings are set" do
      ReportResult.new.friendly_settings.should == []
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
      @r.can_view?(sys_admin).should be_true
    end

    it "allows the same user" do
      @r.can_view?(@u).should be_true
    end

    it "doesn't allow a different user" do
      other_user = User.new
      @r.can_view?(other_user).should be_false
    end
  end

  describe "run report" do
    before :each do
      @file_location = 'spec/support/tmp/sample_report.txt'
      File.delete @file_location if File.exists? @file_location
      class SampleReport
        def self.run_report user, opts
          loc = 'spec/support/tmp/sample_report.txt'
          File.open(loc,'w') {|f| f.write('mystring')}
          File.new loc
        end
      end
      @report_class = SampleReport
      Delayed::Worker.delay_jobs = false
    end
    after :each do
      Delayed::Worker.delay_jobs = true
    end
    it "should write data on report run" do
      ReportResult.any_instance.stub(:execute_report)
      ReportResult.run_report! 'nrr', @u, @report_class, {:settings=>{'o1'=>'o2'},:friendly_settings=>['a','b']}
      found = ReportResult.find_by_name('nrr')
      found.run_by.should == @u
      found.report_class.should == @report_class.to_s
      found.run_at.should > 10.seconds.ago
      found.friendly_settings_json.should == ['a','b'].to_json
      found.settings_json.should == {'o1'=>'o2'}.to_json
    end
    it "enqueues report before running" do
      ReportResult.any_instance.stub(:execute_report)
      ReportResult.run_report! 'ebr', @u, @report_class
      found = ReportResult.find_by_name('ebr')
      found.status.should == "Queued"
    end

    it "sets report as Complete when done" do
      ReportResult.run_report! 'fin', @u, @report_class
      found = ReportResult.find_by_name('fin')
      found.status.should == "Complete"
    end
    it "deletes the underlying file when report is finished" do
      ReportResult.run_report! 'del', @u, @report_class
      File.exists?(@file_location).should be_false
    end
    it "attaches report content to ReportResult" do
      ReportResult.run_report! 'cont', @u, @report_class
      found = ReportResult.find_by_name 'cont'
      rc = found.report_content
      rc.should == "mystring"
    end
    it "writes user message when report is finished" do
      ReportResult.run_report! 'msg', @u, @report_class
      found = ReportResult.find_by_name 'msg'
      m = @u.messages
      m.size.should == 1
      m.first.body.should include "/report_results/#{found.id}/download" #message body includes download link
    end
    it "delays the report with priority 100" do
      ReportResult.any_instance.stub(:execute_report) #don't need report to run
      ReportResult.any_instance.should_receive(:delay).with(:priority=>100).and_return(ReportResult.new)
      ReportResult.run_report! 'delay', @u, @report_class
    end

    it "should run with user settings" do
      SampleReport.should_receive(:run_report) do |run_by|
        User.current.should == run_by
        Time.zone.should == ActiveSupport::TimeZone[run_by.time_zone]

        loc = 'test/assets/sample_report.txt'
        File.open(loc,'w') {|f| f.write('mystring')}
        File.new loc
      end
      ReportResult.run_report! 'user settings', @u, @report_class
    end

    describe "error handling" do
      before(:each) do
        SampleReport.stub(:run_report).and_raise('some error message')
      end
      it "sets reports that threw exceptions as failed" do
        ReportResult.run_report! 'fail', @u, @report_class
        found = ReportResult.find_by_name 'fail'
        found.status.should == "Failed"
      end
      it "writes report errors when failing" do
        ReportResult.run_report! 'err msg', @u, @report_class
        found = ReportResult.find_by_name 'err msg'
        found.run_errors.should == 'some error message'
      end
      it "deletes the underlying file when report fails" do
        ReportResult.run_report! 'uf', @u, @report_class
        File.exists?(@file_location).should be_false
      end
      it "writes a user message containing the word failed in the subject when report fails" do
        ReportResult.run_report! 'um', @u, @report_class
        m = @u.messages
        m.size.should == 1
        m.first.subject.should include "FAILED"
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
      found.should have(3).items
      found.each {|r| r.run_at.should be < 1.week.ago}
    end
    it "should return a purge_at time of 1 week after run_at" do
      report = ReportResult.first
      report.purge_at.should == (report.run_at+1.week)
    end
    it "should return nil for purge_at with no run_at" do
      ReportResult.new.purge_at.should be_nil
    end
    it "should have a purge that actually reports that are eligible for purge" do
      ReportResult.purge
      found = ReportResult.all
      found.should have(3).items
      found.each {|r| r.purge_at.should be > 0.days.ago}
    end
  end

  describe "sanitize callback" do
    it "should sanitize the attached filename" do
      r = ReportResult.new
      r.report_data_file_name = "照片\/:*?\"<>|\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031.jpg"
      r.save
      r.report_data_file_name.should == "___________________________________.jpg"
    end
  end
end
