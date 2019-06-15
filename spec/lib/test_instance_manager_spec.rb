describe OpenChain::TestInstanceManager do
  describe "prep_test_instance" do
    it "should perform prep tasks" do
      expect_any_instance_of(described_class).to receive(:update_master_setup!).with('req', "uuid", "friendly")
      expect_any_instance_of(described_class).to receive(:clear_schedulable_jobs!)
      expect_any_instance_of(described_class).to receive(:clear_scheduled_reports!)
      expect_any_instance_of(described_class).to receive(:update_users!).with('req')
      described_class.prep_test_instance request_host: 'req', uuid: "uuid", friendly_name: "friendly"
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
      MasterSetup.get.update_attributes!(system_code:'oldcode',uuid:'olduuid',suppress_ftp:false,suppress_email:false,custom_features:'cf',request_host:'oldhost')
    end
    
    context "without uuid" do
      it "updates master setup test values" do
        subject.update_master_setup! 'new.request.host', nil, "friendly"
        ms = MasterSetup.first
        expect(ms.system_code).to eq('new') 
        expect(ms.uuid).to eq UUIDTools::UUID.md5_create(UUIDTools::UUID_DNS_NAMESPACE, 'new.request.host').to_s
        expect(ms.suppress_email).to eq true
        expect(ms.suppress_ftp).to eq true
        expect(ms.custom_features).to eq ""
        expect(ms.request_host).to eq 'new.request.host'
        expect(ms.friendly_name).to eq "friendly"
      end
    end

    it "reuses uuid if given" do
      described_class.new.update_master_setup! 'new.request.host', "uuid", "friendly"
      expect(MasterSetup.first.uuid).to eq "uuid"
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
