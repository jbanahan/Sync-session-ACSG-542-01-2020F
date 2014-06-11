require 'spec_helper'

describe OpenChain::CustomHandler::PoloCsmProductGenerator do
  describe :remote_file_name do
    #ChainYYYYMMDDHHSS.csv
    it "should return datestamp naming convention" do
      described_class.new.remote_file_name.should match /Chain[0-9]{14}\.csv/
    end
  end
  describe :ftp_credentials do
    it "should send credentials" do
      c = described_class.new
      c.stub(:remote_file_name).and_return("x.csv")
      c.ftp_credentials.should == {:username=>'polo',:password=>'pZZ117',:server=>'connect.vfitrack.net',:folder=>'/_to_csm',:remote_file_name=>'x.csv'}
    end
  end
  describe :sync_csv do
    after :each do
      @tmp.unlink if @tmp
    end
    it "should split CSM numbers" do
      @cd = Factory(:custom_definition,:module_type=>"Product",:label=>"CSM Number",:data_type=>:text)
      @italy = Factory(:country,:iso_code=>'IT')
      tr = Factory(:tariff_record,:hts_1=>'1234567890',:hts_2=>'123455555',:hts_3=>'0987654321',:classification=>Factory(:classification,:country=>@italy))
      @product = tr.classification.product
      @product.update_custom_value! @cd, "CSM1\nCSM2"
      @tmp = described_class.new.sync_csv
      a = CSV.parse IO.read @tmp
      a[0][1].should == "CSM Number"
      a[1][1].should == "CSM1"
      a[1][6].should == @product.unique_identifier
      a[1][10].should == '1234567890'.hts_format
      a[1][13].should == '123455555'.hts_format
      a[1][16].should == '0987654321'.hts_format
      a[2][1].should == "CSM2"
      a[2][6].should == @product.unique_identifier
      a[2][10].should == '1234567890'.hts_format
    end
    it "should replace newlines with spaces in product data" do
      @cd = Factory(:custom_definition,:module_type=>"Product",:label=>"CSM Number",:data_type=>:text)
      @italy = Factory(:country,:iso_code=>'IT')
      tr = Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:country=>@italy))
      @product = tr.classification.product
      @product.update_custom_value! @cd, "CSM1\nCSM2"
      @product.update_attributes! :name => "A\nB\r\nC"
      @tmp = described_class.new.sync_csv
      a = CSV.parse IO.read @tmp
      a[1][6].should == @product.unique_identifier
      a[1][8].should == 'A B C'
    end
  end
  describe :query do
    before :each do
      @cd = Factory(:custom_definition,:module_type=>"Product",:label=>"CSM Number",:data_type=>:text)
      @italy = Factory(:country,:iso_code=>'IT')
      @tr = Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:country=>@italy))
      @product = @tr.classification.product
      @product.update_custom_value! @cd, 'CSMVAL'
    end
    it "should find product with italian classification that needs sync" do
      r = Product.connection.execute described_class.new.query
      r.first[0].should == @product.id
    end
    it "should use custom where clause" do
      described_class.new(:where=>'WHERE xyz').query.should include "WHERE xyz"
    end
    it "should not find product without italian classification" do
      @product.classifications.destroy_all
      r = Product.connection.execute described_class.new.query
      r.count.should == 0
    end
    it "should not find product without italian hts_1" do
      @product.classifications.first.tariff_records.first.update_attributes(:hts_1=>'')
      r = Product.connection.execute described_class.new.query
      r.count.should == 0
    end
    it "should not find product without CSM number" do
      @product.update_custom_value! @cd, ''
      r = Product.connection.execute described_class.new.query
      r.count.should == 0
    end
    it "should not find product already synced" do
      @product.sync_records.create!(:trading_partner=>described_class.new.sync_code,:sent_at=>10.minutes.ago,:confirmed_at=>5.minutes.ago)
      @product.update_attributes(:updated_at=>1.day.ago)
      r = Product.connection.execute described_class.new.query
      r.count.should == 0
    end
    it "should not return anything other than tariff row 1" do
      @tr.update_attributes! line_number: 2
      r = Product.connection.execute described_class.new.query
      r.count.should == 0
    end
  end
end
