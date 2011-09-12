require 'spec_helper'

describe ReportResult do
  before :each do
    @u = User.create!(:company_id=>Company.create!(:name=>'x').id,:username=>'user1',:password=>'pass123',:password_confirmation=>'pass123',:email=>'a@aspect9.com')
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
     @file_location = 'test/assets/sample_report.txt'
     File.delete @file_location if File.exists? @file_location
     class SampleReport
        def self.run_report user, opts
          loc = 'test/assets/sample_report.txt'
          File.open(loc,'w') {|f| f.write('mystring')}
          File.absolute_path loc
        end
      end
      @report_class = SampleReport
      Delayed::Worker.delay_jobs = false
    end
    it "should write data on report run" do
      ReportResult.any_instance.stub(:execute_report)
      ReportResult.run_report! 'nrr', @u, @report_class, {:settings=>{'o1'=>'o2'},:friendly_settings=>['a','b']}
      found = ReportResult.find_by_name('nrr')
      found.name.should == 'nrr'
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

end
