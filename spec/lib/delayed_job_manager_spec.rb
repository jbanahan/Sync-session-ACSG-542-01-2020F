require 'spec_helper'

describe DelayedJobManager do

  describe 'monitor_backlog' do
    before :each do
      DelayedJobManager.reset_backlog_monitor
    end
    it 'should send message if too many items in queue and oldest job is more than 15 minutes old' do
      oldest = double(:delayed_job)
      oldest.stub!(:created_at).and_return(16.minutes.ago)
      Delayed::Job.should_receive(:find).and_return(oldest)
      Delayed::Job.should_receive(:count).and_return(11)
      RuntimeError.any_instance.should_receive(:log_me)
      DelayedJobManager.monitor_backlog 10
    end
    it 'does not send message if too many items in queue and oldest job is not older of 15 minutes ago' do
      oldest = double(:delayed_job)
      oldest.stub!(:created_at).and_return(14.minutes.ago)
      Delayed::Job.should_receive(:find).and_return(oldest)
      Delayed::Job.should_receive(:count).and_return(11)
      RuntimeError.any_instance.should_not_receive(:log_me)
      DelayedJobManager.monitor_backlog 10
    end
    it 'should not send 2 messages in 30 minutes' do
      oldest = double(:delayed_job)
      oldest.stub!(:created_at).and_return(16.minutes.ago)
      Delayed::Job.should_receive(:find).and_return(oldest)
      Delayed::Job.should_receive(:count).once.and_return(11)
      RuntimeError.any_instance.should_receive(:log_me)
      DelayedJobManager.monitor_backlog 10
      DelayedJobManager.monitor_backlog 10 #this one shouldn't do anything because it hasn't been 30 minutes
    end
  end
 
 describe 'report_delayed_job_errors' do
  before :each do 
    "test".delay.to_s
    @job = Delayed::Job.last
    @job.last_error = "error!"
    @job.save

    @one_hour_ago = 1.hour.ago
    MasterSetup.get.update_attributes(:last_delayed_job_error_sent => @one_hour_ago)
  end
  it 'should send an email if any errors are found on the delayed job queue' do
    # Make sure we're accomplishing sending an email by raising / logging an exception
    DelayedJobManager.report_delayed_job_error
    # This relies on knowing how log_me formats exception emails
    email = ActionMailer::Base.deliveries.last
    email.subject.should include "#{MasterSetup.get.system_code} - 1 delayed job(s) have errors."
    email.body.raw_source.should include "Job Error: error!"

    # Make sure MasterSetup was updated to approximately now
    MasterSetup.last.last_delayed_job_error_sent.should > 1.minute.ago
  end
  it 'should not send an email if no errors are found on the delayed job queue' do
    @job.destroy
    RuntimeError.any_instance.should_not_receive(:log_me)
    DelayedJobManager.report_delayed_job_error

    # Verify that master setup was not updated 
    MasterSetup.last.last_delayed_job_error_sent.to_s(:db).should eq @one_hour_ago.to_s(:db)
  end
  it 'should trim error messages that are over 500 characters long' do
    m = "Really long error message..repeat ad nauseum"
    begin 
      m += m
    end while m.length <= 500
    @job.last_error = m
    @job.save

    # We can just mock the log_me call here since we've already determined that we're sending emails in a previous spec
    RuntimeError.any_instance.should_receive(:log_me).with(["Job Error: " + m.slice(0, 500)], [], true)
    DelayedJobManager.report_delayed_job_error
  end
 end
end
