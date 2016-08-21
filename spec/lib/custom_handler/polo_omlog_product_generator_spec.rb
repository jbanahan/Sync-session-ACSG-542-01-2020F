require 'spec_helper'

describe OpenChain::CustomHandler::PoloOmlogProductGenerator do
  describe "ftp_credentials" do
    it 'should return credentials' do
      expected_credentials = {:server=>'77.93.255.102',:username=>'polo',:password=>'Z%JZp#yUxxH7'}
      expect(described_class.new.ftp_credentials).to eq expected_credentials
    end
  end

  describe "sync_csv" do
    after :each do
      @tmp.unlink if @tmp
    end
    it "should split CSM numbers" do
      @cd = Factory(:custom_definition,:module_type=>"Product",:label=>"CSM Number",:data_type=>:text)
      @italy = Factory(:country,:iso_code=>'IT')
      tr = Factory(:tariff_record,:hts_1=>'1234567890',:hts_2=>'2222222222', :hts_3=>'3333333333', :classification=>Factory(:classification,:country=>@italy))
      @product = tr.classification.product
      @product.update_attributes :name => "Value1\nValue2\r\nValue3"
      @product.update_custom_value! @cd, "CSM1\nCSM2"
      @tmp = described_class.new.sync_csv
      a = CSV.parse IO.read @tmp.path
      expect(a[1][1]).to eq("CSM1")
      expect(a[1][6]).to eq(@product.unique_identifier)
      expect(a[1][8]).to eq('Value1 Value2 Value3')
      expect(a[1][10]).to eq('1234567890'.hts_format)
      expect(a[1][13]).to eq('2222222222'.hts_format)
      expect(a[1][16]).to eq('3333333333'.hts_format)
      expect(a[2][1]).to eq("CSM2")
      expect(a[2][6]).to eq(@product.unique_identifier)
      expect(a[2][8]).to eq('Value1 Value2 Value3')
      expect(a[2][10]).to eq('1234567890'.hts_format)
      expect(a[2][13]).to eq('2222222222'.hts_format)
      expect(a[2][16]).to eq('3333333333'.hts_format)
    end
  end
  describe "query" do
    before :each do
      @cd = Factory(:custom_definition,:module_type=>"Product",:label=>"CSM Number",:data_type=>:text)
      @italy = Factory(:country,:iso_code=>'IT')
      tr = Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:country=>@italy))
      @product = tr.classification.product
      @product.update_custom_value! @cd, 'CSMVAL'
    end
    it "should find product with italian classification that needs sync" do
      r = Product.connection.execute described_class.new.query
      expect(r.first[0]).to eq(@product.id)
    end
    it "should use custom where clause" do
      expect(described_class.new(:where=>'WHERE xyz').query).to include "WHERE xyz"
    end
    it "should not find product without italian classification" do
      @product.classifications.destroy_all
      r = Product.connection.execute described_class.new.query
      expect(r.count).to eq(0)
    end
    it "should not find product without italian hts_1" do
      @product.classifications.first.tariff_records.first.update_attributes(:hts_1=>'')
      r = Product.connection.execute described_class.new.query
      expect(r.count).to eq(0)
    end
    it "should not find product without CSM number" do
      @product.update_custom_value! @cd, ''
      r = Product.connection.execute described_class.new.query
      expect(r.count).to eq(0)
    end
    it "should not find product already synced" do
      @product.sync_records.create!(:trading_partner=>described_class.new.sync_code,:sent_at=>10.minutes.ago,:confirmed_at=>5.minutes.ago)
      @product.update_attributes(:updated_at=>1.day.ago)
      r = Product.connection.execute described_class.new.query
      expect(r.count).to eq(0)
    end
  end
end
