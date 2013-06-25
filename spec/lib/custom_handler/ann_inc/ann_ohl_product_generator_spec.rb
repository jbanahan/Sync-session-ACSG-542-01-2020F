require 'spec_helper'

describe OpenChain::CustomHandler::AnnInc::AnnOhlProductGenerator do
  def run_to_array generator=described_class.new
    @tmp = generator.sync_csv
    CSV.read @tmp.path
  end
  after :each do 
    @tmp.unlink if @tmp
  end
  before :each do
    @us = Factory(:country,:iso_code=>'US')
    @ca = Factory(:country,:iso_code=>'CA')
    helper_class = Class.new do
      include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport
    end
    @helper = helper_class.new
    @cdefs = @helper.prep_custom_definitions [:approved_date,:approved_long,:long_desc_override]
  end
  describe :sync_csv do
    it "should clean newlines from long description" do
      header_row = {0=>'uid',1=>'apprlong',2=>'hts',3=>'schedb',4=>'iso'}
      content_row = {0=>'213',1=>"My Long\nDescription",2=>'1234567890',3=>'9876543210',4=>'US',5=>''}
      gen = described_class.new
      gen.should_receive(:sync).and_yield(header_row).and_yield(content_row)
      r = run_to_array gen
      r.should have(1).record
      r.first.should == ['213','My Long Description','1234567890','9876543210','US']
    end
    it "should force capitalization of ISO codes" do
      header_row = {0=>'uid',1=>'apprlong',2=>'hts',3=>'schedb',4=>'iso',5=>''}
      content_row = {0=>'213',1=>"My Long Description",2=>'1234567890',3=>'9876543210',4=>'us',5=>''}
      gen = described_class.new
      gen.should_receive(:sync).and_yield(header_row).and_yield(content_row)
      r = run_to_array gen
      r.should have(1).record
      r.first.should == ['213','My Long Description','1234567890','9876543210','US']
    end
  end
  describe :query do
    it "should sort US then CA" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:approved_date], 1.day.ago
      p.update_custom_value! @cdefs[:approved_long], "My Long Description"
      [@ca,@us].each_with_index do |cntry,i|
        p.classifications.create!(:country_id=>cntry.id).tariff_records.create!(:hts_1=>"123456789#{i}")
      end
      r = run_to_array
      r[0][4].should == 'US'
      r[1][4].should == 'CA'
    end
    it "should not send products that aren't approved" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:approved_date], 1.day.ago
      p.classifications.create!(:country_id=>@us.id).tariff_records.create!(:hts_1=>"1234567890")
      dont_include = Factory(:product)
      dont_include.classifications.create!(:country_id=>@us.id).tariff_records.create!(:hts_1=>"1234567890")
      r = run_to_array
      r.should have(1).record
      r[0][0].should == p.unique_identifier
    end
    it "should find product with US that needs sync" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:approved_date], 1.day.ago
      p.classifications.create!(:country_id=>@us.id).tariff_records.create!(:hts_1=>"1234567890")
      r = run_to_array
      r.should have(1).record
      r[0][0].should == p.unique_identifier
    end
    it "should find products with CA that need sync" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:approved_date], 1.day.ago
      p.classifications.create!(:country_id=>@ca.id).tariff_records.create!(:hts_1=>"1234567890")
      r = run_to_array
      r.should have(1).record
      r[0][0].should == p.unique_identifier
    end
    it "should not send record with empty HTS" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:approved_date], 1.day.ago
      p.classifications.create!(:country_id=>@us.id).tariff_records.create!(:hts_1=>"1234567890")
      dont_include = Factory(:product)
      dont_include.update_custom_value! @cdefs[:approved_date], 1.day.ago
      dont_include.classifications.create!(:country_id=>@us.id).tariff_records.create!
      r = run_to_array
      r.should have(1).record
      r[0][0].should == p.unique_identifier
    end
    it "should not send other countries besides US & CA" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:approved_date], 1.day.ago
      p.classifications.create!(:country_id=>@us.id).tariff_records.create!(:hts_1=>"1234567890")
      dont_include = Factory(:product)
      dont_include.update_custom_value! @cdefs[:approved_date], 1.day.ago
      dont_include.classifications.create!(:country_id=>Factory(:country,:iso_code=>'CN').id).tariff_records.create!(:hts_1=>"1234567890")
      r = run_to_array
      r.should have(1).record
      r[0][0].should == p.unique_identifier
    end
    it "should not send record that doesn't need sync" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:approved_date], 1.day.ago
      p.classifications.create!(:country_id=>@us.id).tariff_records.create!(:hts_1=>"1234567890")
      dont_include = Factory(:product)
      dont_include.update_custom_value! @cdefs[:approved_date], 1.day.ago
      dont_include.classifications.create!(:country_id=>@us.id).tariff_records.create!(:hts_1=>"1234567890")
      dont_include.sync_records.create!(:trading_partner=>described_class::SYNC_CODE,:sent_at=>1.day.ago,:confirmed_at=>1.minute.ago)
      #reset updated at so that dont_include won't need sync
      ActiveRecord::Base.connection.execute("UPDATE products SET updated_at = '2010-01-01'")
      r = run_to_array
      r.should have(1).record
      r[0][0].should == p.unique_identifier
    end
    it "should use long description override from classification if it exists" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:approved_date], 1.day.ago
      p.update_custom_value! @cdefs[:approved_long], "Don't use me"
      cls = p.classifications.create!(:country_id=>@us.id)
      cls.update_custom_value! @cdefs[:long_desc_override], "Other long description"
      cls.tariff_records.create!(:hts_1=>"1234567890")
      r = run_to_array
      r.should have(1).record
      r[0][0].should == p.unique_identifier
      r[0][1].should == "Other long description"
    end
  end
  describe :ftp_credentials do
    it "should send proper credentials" do
      described_class.new.ftp_credentials.should == {:server=>'ftp2.vandegriftinc.com',:username=>'VFITRACK',:password=>'RL2VFftp',:folder=>'to_ecs/Ann/OHL'}
    end
  end
  it "should have sync_code" do
    described_class.new.sync_code.should == 'ANN-PDM'
  end
end
