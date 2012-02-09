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

end
