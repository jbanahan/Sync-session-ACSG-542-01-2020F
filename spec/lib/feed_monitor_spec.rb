require 'spec_helper'

describe OpenChain::FeedMonitor do
  context "Alliance" do
    before :each do
      MasterSetup.get.update_attributes(:custom_features=>'alliance')
    end
    it "should error if last entry is more than 2 hours ago between M-F 8:00-20:00" do
      Factory(:entry,:source_system=>'Alliance',:updated_at=>Time.new(2012,10,1,4))
      OpenChain::FeedMonitor.monitor Time.new(2012,10,1,12)
      ErrorLogEntry.first.error_message.starts_with?("Alliance not updating").should be_true
    end
    it "should not error if alliance custom feature is not set" do
      MasterSetup.get.update_attributes(:custom_features=>'')
      Factory(:entry,:source_system=>'Alliance',:updated_at=>Time.new(2012,10,1,4))
      OpenChain::FeedMonitor.monitor Time.new(2012,10,1,12)
      ErrorLogEntry.count.should == 0
    end
    it "should not error if outside of time window" do
      Factory(:entry,:source_system=>'Alliance',:updated_at=>Time.new(2012,10,1,4))
      OpenChain::FeedMonitor.monitor Time.new(2012,10,1,21)
      ErrorLogEntry.count.should == 0
    end
    it "should not error if outside of date window" do
      Factory(:entry,:source_system=>'Alliance',:updated_at=>Time.new(2012,10,1,4))
      OpenChain::FeedMonitor.monitor Time.new(2012,9,30,12)
      ErrorLogEntry.count.should == 0
    end
    it "should not error if last entry is less than 2 hours ago" do
      Factory(:entry,:source_system=>'Alliance',:updated_at=>Time.new(2012,10,1,11))
      OpenChain::FeedMonitor.monitor Time.new(2012,10,1,12)
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
      @img.update_attributes(:updated_at=>Time.new(2012,10,1,9))
      OpenChain::FeedMonitor.monitor Time.new(2012,10,1,12)
      ErrorLogEntry.first.error_message.starts_with?("Alliance Imaging not updating.").should be_true
    end
    it "should not error if alliance custom feature is not set" do
      MasterSetup.get.update_attributes(:custom_features=>'')
      @img.update_attributes(:updated_at=>Time.new(2011,10,1))
      OpenChain::FeedMonitor.monitor Time.new(2012,10,1,12)
      ErrorLogEntry.count.should == 0
    end
    it "should not error if outside of time window" do
      @img.update_attributes(:updated_at=>Time.new(2011,10,1))
      OpenChain::FeedMonitor.monitor Time.new(2012,10,1,21)
      ErrorLogEntry.count.should == 0
    end
    it "should not error if outside of date window" do
      @img.update_attributes(:updated_at=>Time.new(2011,9,29))
      OpenChain::FeedMonitor.monitor Time.new(2012,9,30,12)
      ErrorLogEntry.count.should == 0
    end
    it "should not error if last entry is less than 2 hours ago" do
      @img.update_attributes(:updated_at=>Time.new(2012,10,1,11))
      OpenChain::FeedMonitor.monitor Time.new(2012,10,1,12)
      ErrorLogEntry.count.should == 0
    end
  end
  context "Fenix" do
    before :each do
      MasterSetup.get.update_attributes(:custom_features=>'fenix')
    end
    it "should error if last entry is more than 2 hours ago between M-F 8:00-20:00" do
      Factory(:entry,:source_system=>'Fenix',:updated_at=>Time.new(2012,10,1,4))
      OpenChain::FeedMonitor.monitor Time.new(2012,10,1,12)
      ErrorLogEntry.first.error_message.starts_with?("Fenix not updating").should be_true
    end
    it "should not error if fenix custom feature is not set" do
      MasterSetup.get.update_attributes(:custom_features=>'')
      Factory(:entry,:source_system=>'Fenix',:updated_at=>Time.new(2012,10,1,4))
      OpenChain::FeedMonitor.monitor Time.new(2012,10,1,12)
      ErrorLogEntry.count.should == 0
    end
    it "should not error if outside of time window" do
      Factory(:entry,:source_system=>'Fenix',:updated_at=>Time.new(2012,10,1,4))
      OpenChain::FeedMonitor.monitor Time.new(2012,10,1,21)
      ErrorLogEntry.count.should == 0
    end
    it "should not error if outside of date window" do
      Factory(:entry,:source_system=>'Fenix',:updated_at=>Time.new(2012,10,1,4))
      OpenChain::FeedMonitor.monitor Time.new(2012,9,30,12)
      ErrorLogEntry.count.should == 0
    end
    it "should not error if last entry is less than 2 hours ago" do
      Factory(:entry,:source_system=>'Fenix',:updated_at=>Time.new(2012,10,1,11))
      OpenChain::FeedMonitor.monitor Time.new(2012,10,1,12)
      ErrorLogEntry.count.should == 0
    end
  end
end
