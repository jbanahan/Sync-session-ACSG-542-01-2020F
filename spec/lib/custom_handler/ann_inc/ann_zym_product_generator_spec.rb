require 'spec_helper'

describe OpenChain::CustomHandler::AnnInc::AnnZymProductGenerator do
  def run_to_array generator=described_class.new
    @tmp = generator.sync_csv
    CSV.read @tmp.path, col_sep:'|' #these are pipe delimited files
  end
  after :each do 
    @tmp.unlink if @tmp
  end
  before :each do
    @cdefs = described_class.prep_custom_definitions [:approved_date,:approved_long,:long_desc_override,:origin,:article, :related_styles]
  end
  describe :sync_csv do
    it "should clean newlines from long description" do
      header_row = {0=>'uid',1=>'imp',2=>'ldesc',3=>'org',4=>'hts'}
      content_row = {0=>'213',1=>'US',2=>"My Long\nDescription",3=>'CA',4=>'9876543210',5=>''}
      gen = described_class.new
      gen.should_receive(:sync).and_yield(header_row).and_yield(content_row)
      r = run_to_array gen
      r.should have(1).record
      r.first.should == ['213','US','My Long Description','CA','9876543210']
    end
    it "should not quote empty fields" do
      header_row = {0=>'uid',1=>'imp',2=>'ldesc',3=>'org',4=>'hts'}
      content_row = {0=>'213',1=>'US',2=>"",3=>'',4=>'9876543210',5=>''}
      gen = described_class.new
      gen.should_receive(:sync).and_yield(header_row).and_yield(content_row)
      @tmp = gen.sync_csv
      r = IO.read(@tmp)
      r.should == "213|US|||9876543210\n"
    end
  end
  describe :query do
    before :each do
      @us = Factory(:country,:iso_code=>'US')
    end
    it "should split mulitple countries of origin into separate rows" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:article], 'ZSCR'
      p.update_custom_value! @cdefs[:origin], "MX\nCN"
      p.update_custom_value! @cdefs[:approved_long], 'LD'
      cls = p.classifications.create!(:country_id=>@us.id)
      cls.tariff_records.create!(:hts_1=>"1234567890")
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      r = run_to_array
      r.should have(2).records
      r.first.should == [p.unique_identifier,'US','LD','MX','1234567890'] 
      r.last.should ==  [p.unique_identifier,'US','LD','CN','1234567890']
    end
    it "should not output style without ZSCR article type" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:article], 'ZSCR'
      p.update_custom_value! @cdefs[:origin], 'MX'
      p.update_custom_value! @cdefs[:approved_long], 'LD'
      cls = p.classifications.create!(:country_id=>@us.id)
      cls.tariff_records.create!(:hts_1=>"1234567890")
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      p2 = Factory(:product)
      p2.update_custom_value! @cdefs[:article], 'ZSCR-X'
      p2.update_custom_value! @cdefs[:origin], 'MX'
      p2.update_custom_value! @cdefs[:approved_long], 'LD'
      cls2 = p2.classifications.create!(:country_id=>@us.id)
      cls2.tariff_records.create!(:hts_1=>"1234567890")
      cls2.update_custom_value! @cdefs[:approved_date], 1.day.ago
      r = run_to_array
      r.should have(1).records
      r.first.first.should == p.unique_identifier
    end
    it "should only output US" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:article], 'ZSCR'
      p.update_custom_value! @cdefs[:origin], 'MX'
      p.update_custom_value! @cdefs[:approved_long], 'LD'
      [@us,Factory(:country,:iso_code=>'CN')].each do |c|
        cls = p.classifications.create!(:country_id=>c.id)
        cls.tariff_records.create!(:hts_1=>'1234567890')
        cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      end
      r = run_to_array
      r.should have(1).record
      r.first.should == [p.unique_identifier,'US','LD','MX','1234567890'] 
    end
    it "should only output records that need sync" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:article], 'ZSCR'
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
      r.should have(1).record
      r[0][0].should == p.unique_identifier
    end
    it "should only output approved products" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:article], 'ZSCR'
      cls = p.classifications.create!(:country_id=>@us.id)
      cls.tariff_records.create!(:hts_1=>"1234567890")
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      dont_include = Factory(:product)
      dont_include.classifications.create!(:country_id=>@us.id).tariff_records.create!(:hts_1=>"1234567890")
      r = run_to_array
      r.should have(1).record
      r[0][0].should == p.unique_identifier
    end
    it "should use long description override from classification if it exists" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:article], 'ZSCR'
      p.update_custom_value! @cdefs[:approved_long], "Don't use me"
      cls = p.classifications.create!(:country_id=>@us.id)
      cls.update_custom_value! @cdefs[:long_desc_override], "Other long description"
      cls.tariff_records.create!(:hts_1=>"1234567890")
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      r = run_to_array
      r.should have(1).record
      r[0][0].should == p.unique_identifier
      r[0][2].should == "Other long description"
    end

    it "should handle sending multiple lines for related styles" do
      p = Factory(:product,unique_identifier:'M-Style')
      p.update_custom_value! @cdefs[:article], 'ZSCR'
      cls = p.classifications.create!(:country_id=>@us.id)
      cls.tariff_records.create!(:hts_1=>"1234567890")
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago

      p.update_custom_value! @cdefs[:related_styles], "P-Style\nT-Style"

      r = run_to_array
      r.should have(3).records
      r[0][0].should == p.unique_identifier
      r[1][0].should == "P-Style"
      r[2][0].should == "T-Style"
    end

    it "should handle sending multiple lines for related styles and countries" do
      p = Factory(:product,unique_identifier:'M-Style')
      p.update_custom_value! @cdefs[:article], 'ZSCR'
      # Use the country split as well so we make sure both line explosions are working together
      p.update_custom_value! @cdefs[:origin], "MX\nCN"
      cls = p.classifications.create!(:country_id=>@us.id)
      cls.tariff_records.create!(:hts_1=>"1234567890")
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago

      p.update_custom_value! @cdefs[:related_styles], "P-Style\nT-Style"

      r = run_to_array
      r.should have(6).records
      r[0][0].should == "M-Style"
      r[1][0].should == "M-Style"
      r[2][0].should == "P-Style"
      r[3][0].should == "P-Style"
      r[4][0].should == "T-Style"
      r[5][0].should == "T-Style"
    end

    it "should not output same record twice based on fingerprint" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:article], 'ZSCR'
      cls = p.classifications.create!(:country_id=>@us.id)
      cls.tariff_records.create!(:hts_1=>"1234567890")
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago

      p2 = Factory(:product)
      p2.update_custom_value! @cdefs[:article], 'ZSCR'
      cls2 = p2.classifications.create!(:country_id=>@us.id)
      cls2.tariff_records.create!(:hts_1=>"1234567890")
      cls2.update_custom_value! @cdefs[:approved_date], 1.day.ago

      r = run_to_array
      r.should have(2).records

      p.update_attributes(updated_at:1.day.from_now) #shouldn't matter because hash doesn't change
      cls2.tariff_records.first.update_attributes(hts_1:'987654321') #should change hash forcing new record

      r = run_to_array
      r.should have(1).records
      r[0][0].should == p.unique_identifier
    end
  end
  it "should have sync code" do
    described_class.new.sync_code.should == 'ANN-ZYM'
  end
  context :ftp do
    it "should send proper credentials" do
      described_class.new.ftp_credentials.should == {:server=>'ftp2.vandegriftinc.com',:username=>'VFITRACK',:password=>'RL2VFftp',:folder=>'to_ecs/Ann/ZYM'}
    end
  end
end
