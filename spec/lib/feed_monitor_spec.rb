require 'spec_helper'

describe OpenChain::FeedMonitor do
  before :each do
    @est = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
  end

  context "Alliance" do
    before :each do
      MasterSetup.get.update_attributes(:custom_features=>'alliance')
    end
    it "should error if last entry is more than 2 hours ago between M-F 8:00-20:00" do
      Factory(:entry,:source_system=>'Alliance',:last_exported_from_source=>@est.parse("2012-10-01 4:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-10-01 12:00")
      ErrorLogEntry.first.error_message.starts_with?("Alliance not updating").should be_true
    end
    it "should not error if alliance custom feature is not set" do
      MasterSetup.get.update_attributes(:custom_features=>'')
      Factory(:entry,:source_system=>'Alliance',:last_exported_from_source=>@est.parse("2012-10-01 4:00"))
      OpenChain::FeedMonitor.monitor@est.parse("2012-10-01 12:00")
      ErrorLogEntry.count.should == 0
    end
    it "should not error if outside of time window" do
      Factory(:entry,:source_system=>'Alliance',:last_exported_from_source=>@est.parse("2012-10-01 4:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-10-01 21:00")
      ErrorLogEntry.count.should == 0
    end
    it "should not error if outside of date window" do
      Factory(:entry,:source_system=>'Alliance',:last_exported_from_source=>@est.parse("2012-10-01 4:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-09-30 12:00")
      ErrorLogEntry.count.should == 0
    end
    it "should not error if last entry is less than 2 hours ago" do
      Factory(:entry,:source_system=>'Alliance',:last_exported_from_source=>@est.parse("2012-10-01 11:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-10-01 12:00")
      ErrorLogEntry.count.should == 0
    end
  end
  context "Alliance Images" do
    before :each do 
      MasterSetup.get.update_attributes(:custom_features=>'alliance')
      @ent = Factory(:entry,:source_system=>'Alliance')
      @img = @ent.attachments.create!
    end
    it "should error if last image is more than 2 hours ago between M-F 8:00-20:00" do
      @img.update_attributes(:updated_at=>@est.parse("2012-10-01 9:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-10-01 12:00")
      ErrorLogEntry.first.error_message.starts_with?("Alliance Imaging not updating.").should be_true
    end
    it "should not error if alliance custom feature is not set" do
      MasterSetup.get.update_attributes(:custom_features=>'')
      @img.update_attributes(:updated_at=>@est.parse("2011-10-01 00:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2011-10-01 12:00")
      ErrorLogEntry.count.should == 0
    end
    it "should not error if outside of time window" do
      @img.update_attributes(:updated_at=>@est.parse("2011-10-01 00:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2011-10-01 21:00")
      ErrorLogEntry.count.should == 0
    end
    it "should not error if outside of date window" do
      @img.update_attributes(:updated_at=>@est.parse("2012-09-29 00:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-09-30 12:00")
      ErrorLogEntry.count.should == 0
    end
    it "should not error if last entry is less than 2 hours ago" do
      @img.update_attributes(:updated_at=>@est.parse("2011-10-01 11:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2011-10-01 12:00")
      ErrorLogEntry.count.should == 0
    end
  end
  context "Fenix" do
    before :each do
      MasterSetup.get.update_attributes(:custom_features=>'fenix')
    end
    it "should error if last entry is more than 2 hours ago between M-F 8:00-20:00 EST" do
      Factory(:entry,:source_system=>'Fenix',:last_exported_from_source=>@est.parse("2012-10-01 4:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-10-01 12:00")
      ErrorLogEntry.first.error_message.starts_with?("Fenix not updating").should be_true
    end
    it "should not error if fenix custom feature is not set" do
      MasterSetup.get.update_attributes(:custom_features=>'')
      Factory(:entry,:source_system=>'Fenix',:last_exported_from_source=>@est.parse("2012-10-01 4:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-10-01 12:00")
      ErrorLogEntry.count.should == 0
    end
    it "should not error if outside of time window" do
      Factory(:entry,:source_system=>'Fenix',:last_exported_from_source=>@est.parse("2012-10-01 4:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-10-01 21:00")
      ErrorLogEntry.count.should == 0
    end
    it "should not error if error on weekend during business hours" do
      Factory(:entry,:source_system=>'Fenix',:last_exported_from_source=>@est.parse("2012-10-01 4:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-10-06 8:00")
      ErrorLogEntry.count.should == 0
    end
    it "should not error if outside of date window" do
      Factory(:entry,:source_system=>'Fenix',:last_exported_from_source=>@est.parse("2012-10-01 4:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-9-30 12:00")
      ErrorLogEntry.count.should == 0
    end
    it "should not error if last entry is less than 2 hours ago" do
      Factory(:entry,:source_system=>'Fenix',:last_exported_from_source=>@est.parse("2012-10-01 11:00"))
      OpenChain::FeedMonitor.monitor @est.parse("2012-10-01 21:00")
      ErrorLogEntry.count.should == 0
    end
  end
end
