describe OpenChain::FeedMonitor do
  before :each do
    @est = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
  end

  context "Alliance" do

    let! (:master_setup) {
      ms = stub_master_setup
      allow(ms).to receive(:custom_feature?).with("alliance").and_return true
      ms
    }

    it "should error if last entry is more than 2 hours ago between M-F 8:00-20:00" do
      Factory(:entry,:source_system=>'Alliance',:last_exported_from_source=>@est.parse("2012-10-01 4:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-10-01 12:00")
      expect(ErrorLogEntry.first.error_message.starts_with?("Alliance not updating")).to be_truthy
    end
    it "should not error if alliance custom feature is not set" do
      expect(master_setup).to receive(:custom_feature?).with("alliance").and_return false
      Factory(:entry,:source_system=>'Alliance',:last_exported_from_source=>@est.parse("2012-10-01 4:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-10-01 12:00")
      expect(ErrorLogEntry.count).to eq(0)
    end
    it "should not error if outside of time window" do
      Factory(:entry,:source_system=>'Alliance',:last_exported_from_source=>@est.parse("2012-10-01 4:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-10-01 21:00")
      expect(ErrorLogEntry.count).to eq(0)
    end
    it "should not error if outside of date window" do
      Factory(:entry,:source_system=>'Alliance',:last_exported_from_source=>@est.parse("2012-10-01 4:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-09-30 12:00")
      expect(ErrorLogEntry.count).to eq(0)
    end
    it "should not error if last entry is less than 2 hours ago" do
      Factory(:entry,:source_system=>'Alliance',:last_exported_from_source=>@est.parse("2012-10-01 11:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-10-01 12:00")
      expect(ErrorLogEntry.count).to eq(0)
    end
  end

  context "Alliance Images" do

    let! (:master_setup) {
      ms = stub_master_setup
      allow(ms).to receive(:custom_feature?).with("alliance").and_return true
      ms
    }

    before :each do
      @ent = Factory(:entry,:source_system=>'Alliance')
      @img = @ent.attachments.create!
    end
    it "should error if last image is more than 2 hours ago between M-F 8:00-20:00" do
      @img.update_attributes(:updated_at=>@est.parse("2012-10-01 9:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-10-01 12:00")
      expect(ErrorLogEntry.first.error_message.starts_with?("Alliance Imaging not updating.")).to be_truthy
    end
    it "should not error if alliance custom feature is not set" do
      expect(master_setup).to receive(:custom_feature?).with("alliance").and_return false
      @img.update_attributes(:updated_at=>@est.parse("2011-10-01 00:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2011-10-01 12:00")
      expect(ErrorLogEntry.count).to eq(0)
    end
    it "should not error if outside of time window" do
      @img.update_attributes(:updated_at=>@est.parse("2011-10-01 00:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2011-10-01 21:00")
      expect(ErrorLogEntry.count).to eq(0)
    end
    it "should not error if outside of date window" do
      @img.update_attributes(:updated_at=>@est.parse("2012-09-29 00:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-09-30 12:00")
      expect(ErrorLogEntry.count).to eq(0)
    end
    it "should not error if last entry is less than 2 hours ago" do
      @img.update_attributes(:updated_at=>@est.parse("2011-10-01 11:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2011-10-01 12:00")
      expect(ErrorLogEntry.count).to eq(0)
    end
  end
  context "Fenix" do

    let! (:master_setup) {
      ms = stub_master_setup
      allow(ms).to receive(:custom_feature?).with("fenix").and_return true
      ms
    }

    it "should error if last entry is more than 2 hours ago between M-F 8:00-20:00 EST" do
      Factory(:entry,:source_system=>'Fenix',:last_exported_from_source=>@est.parse("2012-10-01 4:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-10-01 12:00")
      expect(ErrorLogEntry.first.error_message.starts_with?("Fenix not updating")).to be_truthy
    end
    it "should not error if fenix custom feature is not set" do
      expect(master_setup).to receive(:custom_feature?).with("fenix").and_return false
      Factory(:entry,:source_system=>'Fenix',:last_exported_from_source=>@est.parse("2012-10-01 4:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-10-01 12:00")
      expect(ErrorLogEntry.count).to eq(0)
    end
    it "should not error if outside of time window" do
      Factory(:entry,:source_system=>'Fenix',:last_exported_from_source=>@est.parse("2012-10-01 4:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-10-01 21:00")
      expect(ErrorLogEntry.count).to eq(0)
    end
    it "should not error if error on weekend during business hours" do
      Factory(:entry,:source_system=>'Fenix',:last_exported_from_source=>@est.parse("2012-10-01 4:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-10-06 8:00")
      expect(ErrorLogEntry.count).to eq(0)
    end
    it "should not error if outside of date window" do
      Factory(:entry,:source_system=>'Fenix',:last_exported_from_source=>@est.parse("2012-10-01 4:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-9-30 12:00")
      expect(ErrorLogEntry.count).to eq(0)
    end
    it "should not error if last entry is less than 2 hours ago" do
      Factory(:entry,:source_system=>'Fenix',:last_exported_from_source=>@est.parse("2012-10-01 11:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-10-01 21:00")
      expect(ErrorLogEntry.count).to eq(0)
    end
  end
end
