require 'spec_helper'

describe DelayedJobManager do

  describe 'monitor_backlog' do
    before :each do
      DelayedJobManager.reset_backlog_monitor
    end
    it 'should send message if too many items older than 10 minutes are in the queue' do   
      "word".delay({run_at: 15.minutes.ago}).size
      "word".delay({run_at: 15.minutes.ago}).size
      "word".delay({run_at: 15.minutes.ago}).size
      DelayedJobManager.monitor_backlog 2
      email = ActionMailer::Base.deliveries.last
      expect(email).not_to be_nil
      expect(email.subject).to include "#{MasterSetup.get.system_code} - Delayed Job Queue Too Big: 3 Items" 
    end
    it 'does not send message if number of items in the queue less than 10 minutes old is at or below the limit' do
      "word".delay({run_at: 5.minutes.ago}).size
      "word".delay({run_at: 15.minutes.ago}).size
      "word".delay({run_at: 15.minutes.ago}).size
      DelayedJobManager.monitor_backlog 2
      email = ActionMailer::Base.deliveries.last
      expect(email).to be_nil
    end
    it 'should not send 2 messages in 30 minutes' do
      "word".delay({run_at: 15.minutes.ago}).size
      "word".delay({run_at: 15.minutes.ago}).size
      "word".delay({run_at: 15.minutes.ago}).size
      DelayedJobManager.monitor_backlog 2
      email1 = ActionMailer::Base.deliveries.last
      DelayedJobManager.monitor_backlog 2 #this one shouldn't do anything because it hasn't been 30 minutes
      email2 = ActionMailer::Base.deliveries.last
      expect(email1).not_to be_nil
      expect(email1).to eq(email2)
    end
  end
 
 describe 'report_delayed_job_error' do
  before :each do 
    @job = Delayed::Job.new
    @job.last_error = "error!"
    @job.created_at = Time.zone.now
    @job.save

    @one_hour_ago = Time.zone.now - 1.hour
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
    MasterSetup.get.last_delayed_job_error_sent.should > 1.minute.ago
  end
  it 'should not send an email if no errors are found on the delayed job queue' do
    @job.destroy
    RuntimeError.any_instance.should_not_receive(:log_me)
    DelayedJobManager.report_delayed_job_error

    # Verify that master setup was not updated 
    MasterSetup.get.last_delayed_job_error_sent.to_s(:db).should eq @one_hour_ago.to_s(:db)
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
  it 'should not send an email if a previous email was sent less than X minutes ago' do
    reporting_age = 60.minutes.ago
    MasterSetup.get.last_delayed_job_error_sent = reporting_age
    RuntimeError.any_instance.should_not_receive(:log_me)

    # Add a minute to our max reporting age due to timing concerns
    DelayedJobManager.report_delayed_job_error(61)

    MasterSetup.get.last_delayed_job_error_sent.to_s(:db).should eq reporting_age.to_s(:db)
  end
  it 'should not add more than 50 error messages to an error notification email' do 
    (1..50).each do |n|
      new_job = Delayed::Job.new
      new_job.last_error = "error - #{n}"
      new_job.created_at = Time.now + n.minutes
      new_job.save
    end
    
    DelayedJobManager.report_delayed_job_error

    email = ActionMailer::Base.deliveries.last
    email.subject.should include "#{MasterSetup.get.system_code} - 51 delayed job(s) have errors."
    email.body.raw_source.should include "Job Error: error - 50"
    # Since @job has already been saved above and is the oldest job record, it should
    # not appear in our messages
    email.body.raw_source.should_not include "Job Error: " + @job.last_error
  end
  it "should ignore delayed job upgrade requeue messages" do
    @job.last_error = "This job queue was running the outdated code version"
    @job.save
    
    RuntimeError.any_instance.should_not_receive(:log_me)
    DelayedJobManager.report_delayed_job_error

    # Verify that master setup was not updated 
    MasterSetup.get.last_delayed_job_error_sent.to_s(:db).should eq @one_hour_ago.to_s(:db)
  end
 end
end
