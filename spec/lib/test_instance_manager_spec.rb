require 'spec_helper'

describe OpenChain::TestInstanceManager do
  describe "prep_test_instance" do
    it "should perform prep tasks" do
      expect_any_instance_of(described_class).to receive(:update_master_setup!).with('req', "uuid")
      expect_any_instance_of(described_class).to receive(:clear_schedulable_jobs!)
      expect_any_instance_of(described_class).to receive(:clear_scheduled_reports!)
      expect_any_instance_of(described_class).to receive(:update_users!).with('req')
      described_class.prep_test_instance 'req', "uuid"
    end
  end
  describe "clear_schedulable_jobs" do
    it "should clear jobs" do
      sj = SchedulableJob.create!
      described_class.new.clear_schedulable_jobs!
      expect(SchedulableJob.all).to be_empty
    end
  end
  describe "clear_scheduled_reports" do
    it "should clear scheduled reports" do
      ss = Factory(:search_schedule)
      described_class.new.clear_scheduled_reports!
      expect(SearchSchedule.all).to be_empty
    end
  end
  describe "update_master_setup" do
    before :each do 
      MasterSetup.get.update_attributes(system_code:'oldcode',uuid:'olduuid',ftp_polling_active:true,custom_features:'cf',request_host:'oldhost')
    end
    context "without uuid" do
      before :each do      
        described_class.new.update_master_setup! 'new.request.host', nil
      end
      it "should change system code" do
        expect(MasterSetup.get.system_code).to eq('new') 
      end
      it "should change UUID" do
        expect(MasterSetup.get.uuid).to eq UUIDTools::UUID.md5_create(UUIDTools::UUID_DNS_NAMESPACE, 'new.request.host').to_s
      end
      it "should disable FTP polling" do
        expect(MasterSetup.get).not_to be_ftp_polling_active
      end
      it "should clear custom features" do
        expect(MasterSetup.get.custom_features).to be_blank
      end
      it "should set request host" do
        expect(MasterSetup.get.request_host).to eq('new.request.host')
      end
    end

    it "reuses uuid if given" do
      described_class.new.update_master_setup! 'new.request.host', "uuid"
      expect(MasterSetup.get.uuid).to eq "uuid"
    end
  end
  describe "update_users" do
    it "should clear tariff_subscribed flags" do
      u = Factory(:user,tariff_subscribed:true)
      described_class.new.update_users! "localhost"
      u.reload
      expect(u).not_to be_tariff_subscribed
      expect(u.host_with_port).to eq "localhost"
    end
  end
end
