require 'spec_helper'

describe OpenChain::TestInstanceManager do
  describe :prep_test_instance do
    it "should perform prep tasks" do
      described_class.any_instance.should_receive(:update_master_setup!).with('req')
      described_class.any_instance.should_receive(:clear_schedulable_jobs!)
      described_class.any_instance.should_receive(:clear_scheduled_reports!)
      described_class.any_instance.should_receive(:update_users!)
      described_class.prep_test_instance 'req'
    end
  end
  describe :clear_schedulable_jobs do
    it "should clear jobs" do
      sj = SchedulableJob.create!
      described_class.new.clear_schedulable_jobs!
      SchedulableJob.all.should be_empty
    end
  end
  describe :clear_scheduled_reports do
    it "should clear scheduled reports" do
      ss = Factory(:search_schedule)
      described_class.new.clear_scheduled_reports!
      SearchSchedule.all.should be_empty
    end
  end
  describe :update_master_setup do
    before :each do
      MasterSetup.get.update_attributes(system_code:'oldcode',uuid:'olduuid',ftp_polling_active:true,custom_features:'cf',request_host:'oldhost')
      described_class.new.update_master_setup! 'new.request.host'
    end
    it "should change system code" do
      MasterSetup.get.system_code.should == 'new.request.host' 
    end
    it "should change UUID" do
      MasterSetup.get.uuid.size.should == 36
    end
    it "should disable FTP polling" do
      MasterSetup.get.should_not be_ftp_polling_active
    end
    it "should clear custom features" do
      MasterSetup.get.custom_features.should be_blank
    end
    it "should set request host" do
      MasterSetup.get.request_host.should == 'new.request.host'
    end
  end
  describe :update_users do
    it "should clear tariff_subscribed flags" do
      u = Factory(:user,tariff_subscribed:true)
      described_class.new.update_users!
      u.reload
      u.should_not be_tariff_subscribed
    end
  end
end
