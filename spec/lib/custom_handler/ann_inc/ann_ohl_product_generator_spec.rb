require 'spec_helper'

describe OpenChain::CustomHandler::AnnInc::AnnOhlProductGenerator do
  def run_to_array generator=described_class.new
    @tmp = generator.sync_csv
    CSV.read @tmp.path
  end
  before :all do
    described_class.prep_custom_definitions [:approved_date,:approved_long,:long_desc_override, :related_styles]
  end
  after :all do
    CustomDefinition.where('1=1').destroy_all
  end
  after :each do 
    @tmp.unlink if @tmp
  end
  before :each do
    @us = Factory(:country,:iso_code=>'US')
    @ca = Factory(:country,:iso_code=>'CA')
    @cdefs = described_class.prep_custom_definitions [:approved_date,:approved_long,:long_desc_override, :related_styles]
  end
  describe "sync_csv" do
    it "should clean newlines from long description" do
      content_row = {0=>'213',1=>"My Long\nDescription",2=>'1234567890',3=>'9876543210',4=>'US',5=>''}
      gen = described_class.new
      expect(gen).to receive(:sync).with(include_headers: false).and_yield(content_row)
      r = run_to_array gen
      expect(r.size).to eq(1)
      expect(r.first).to eq(['213','My Long Description','1234567890','9876543210','US'])
    end
    it "should force capitalization of ISO codes" do
      content_row = {0=>'213',1=>"My Long Description",2=>'1234567890',3=>'9876543210',4=>'us',5=>''}
      gen = described_class.new
      expect(gen).to receive(:sync).and_yield(content_row)
      r = run_to_array gen
      expect(r.size).to eq(1)
      expect(r.first).to eq(['213','My Long Description','1234567890','9876543210','US'])
    end
  end
  describe "query" do
    it "should sort US then CA and not include other countries" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:approved_long], "My Long Description"
      [@ca,@us,Factory(:country,:iso_code=>'CN')].each_with_index do |cntry,i|
        cls = p.classifications.create!(:country_id=>cntry.id)
        cls.tariff_records.create!(:hts_1=>"123456789#{i}")
        cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      end
      r = run_to_array
      expect(r.size).to eq(2)
      expect(r[0][4]).to eq('US')
      expect(r[1][4]).to eq('CA')
    end
    it "should not send classifications that aren't approved" do
      p = Factory(:product)
      cls = p.classifications.create!(:country_id=>@us.id)
      cls.tariff_records.create!(:hts_1=>"1234567890")
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      p.classifications.create!(:country_id=>@ca.id).tariff_records.create!(:hts_1=>'1234567899')
      
      dont_include = Factory(:product)
      dont_include.classifications.create!(:country_id=>@us.id).tariff_records.create!(:hts_1=>"1234567890")
      r = run_to_array
      expect(r.size).to eq(1)
      expect(r[0][0]).to eq(p.unique_identifier)
    end
    it "should not send record with empty HTS" do
      p = Factory(:product)
      cls = p.classifications.create!(:country_id=>@us.id)
      cls.tariff_records.create!(:hts_1=>"1234567890")
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      dont_include = Factory(:product)
      d_cls = dont_include.classifications.create!(:country_id=>@us.id)
      d_cls.tariff_records.create!
      d_cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      r = run_to_array
      expect(r.size).to eq(1)
      expect(r[0][0]).to eq(p.unique_identifier)
    end
    it "should not send record that doesn't need sync" do
      p = Factory(:product)
      cls = p.classifications.create!(:country_id=>@us.id)
      cls.tariff_records.create!(:hts_1=>"1234567890")
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      dont_include = Factory(:product)
      d_cls = dont_include.classifications.create!(:country_id=>@us.id)
      d_cls.tariff_records.create!(:hts_1=>"1234567890")
      d_cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      dont_include.sync_records.create!(:trading_partner=>described_class::SYNC_CODE,:sent_at=>1.day.ago,:confirmed_at=>1.minute.ago)
      #reset updated at so that dont_include won't need sync
      ActiveRecord::Base.connection.execute("UPDATE products SET updated_at = '2010-01-01'")
      r = run_to_array
      expect(r.size).to eq(1)
      expect(r[0][0]).to eq(p.unique_identifier)
    end
    it "should use long description override from classification if it exists" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:approved_long], "Don't use me"
      cls = p.classifications.create!(:country_id=>@us.id)
      cls.update_custom_value! @cdefs[:long_desc_override], "Other long description"
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      cls.tariff_records.create!(:hts_1=>"1234567890")
      r = run_to_array
      expect(r.size).to eq(1)
      expect(r[0][0]).to eq(p.unique_identifier)
      expect(r[0][1]).to eq("Other long description")
    end
    it "should not send multiple lines for sets" do
      p = Factory(:product)
      cls = p.classifications.create!(:country_id=>@us.id)
      #creating tariff_records out of order to ensure we always get the lowest line number
      cls.tariff_records.create!(:hts_1=>"1234444444",:line_number=>2)
      cls.tariff_records.create!(:hts_1=>"1234567890",:line_number=>1)
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      r = run_to_array
      expect(r.size).to eq(1)
      expect(r[0][0]).to eq(p.unique_identifier)
      expect(r[0][2]).to eq('1234567890')
    end
    it "should handle sending multiple lines for related styles" do
      p = Factory(:product)
      cls = p.classifications.create!(:country_id=>@us.id)
      cls.tariff_records.create!(:hts_1=>"1234567890",:line_number=>1)
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago

      p.update_custom_value! @cdefs[:related_styles], "T-Style\nP-Style"

      r = run_to_array
      expect(r.size).to eq(3)
      expect(r[0][0]).to eq(p.unique_identifier)
      expect(r[1][0]).to eq("T-Style")
      expect(r[2][0]).to eq("P-Style")
    end
    it "should ensure multiple country lines for related styles are ordered together by style value" do
      p = Factory(:product)
      cls = p.classifications.create!(:country_id=>@us.id)
      cls.tariff_records.create!(:hts_1=>"1234567890",:line_number=>1)
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago

      ca_cls = p.classifications.create!(:country_id=>@ca.id)
      ca_cls.tariff_records.create!(:hts_1=>"1234567890",:line_number=>1)
      ca_cls.update_custom_value! @cdefs[:approved_date], 1.day.ago

      p.update_custom_value! @cdefs[:related_styles], "T-Style\nP-Style"

      r = run_to_array
      expect(r.size).to eq(6)
      expect(r[0][0]).to eq(p.unique_identifier)
      expect(r[0][4]).to eq("US")
      expect(r[1][0]).to eq(p.unique_identifier)
      expect(r[1][4]).to eq("CA")
      expect(r[2][0]).to eq("T-Style")
      expect(r[2][4]).to eq("US")
      expect(r[3][0]).to eq("T-Style")
      expect(r[3][4]).to eq("CA")
      expect(r[4][0]).to eq("P-Style")
      expect(r[4][4]).to eq("US")
      expect(r[5][0]).to eq("P-Style")
      expect(r[5][4]).to eq("CA")
    end
    it "handles multiple product records" do
      p = Factory(:product)
      p2 = Factory(:product)

      cls = p.classifications.create!(:country_id=>@us.id)
      cls.tariff_records.create!(:hts_1=>"1234567890",:line_number=>1)
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago

      cls = p2.classifications.create!(:country_id=>@ca.id)
      cls.tariff_records.create!(:hts_1=>"1234567890",:line_number=>1)
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago

      r = run_to_array
      expect(r.size).to eq(2)
      expect(r[0][0]).to eq(p.unique_identifier)
      expect(r[1][0]).to eq(p2.unique_identifier)

      # verify that each product also has a sync record
      expect(p.sync_records.length).to eq 1
      expect(p2.sync_records.length).to eq 1
    end
  end
  describe "ftp_credentials" do
    it "should send proper credentials" do
      expect(described_class.new.ftp_credentials).to eq({:server=>'ftp2.vandegriftinc.com',:username=>'VFITRACK',:password=>'RL2VFftp',:folder=>'to_ecs/Ann/OHL',:protocol=>"sftp"})
    end
  end
  it "should have sync_code" do
    expect(described_class.new.sync_code).to eq('ANN-PDM')
  end
end
