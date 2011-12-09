require 'spec_helper'

describe DelayedJobManager do

  describe 'monitor_backlog' do
    before :each do
      DelayedJobManager.reset_backlog_monitor
    end
    it 'should send message if too many items in queue' do
      Delayed::Job.should_receive(:count).and_return(11)
      RuntimeError.any_instance.should_receive(:log_me)
      DelayedJobManager.monitor_backlog 10
    end
    it 'should not send 2 messages in 30 minutes' do
      Delayed::Job.should_receive(:count).once.and_return(11)
      RuntimeError.any_instance.should_receive(:log_me)
      DelayedJobManager.monitor_backlog 10
      DelayedJobManager.monitor_backlog 10 #this one shouldn't do anything because it hasn't been 30 minutes
    end
  end

end
