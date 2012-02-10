require 'spec_helper'

describe OpenChain::BulkUpdateClassification do
  describe 'build_common_classifications' do
    before :each do
      @products = 2.times.collect {Factory(:product)}
      @country = Factory(:country)
      @hts = '1234567890'
      @products.each do |p|
        p.classifications.create!(:country_id=>@country.id).tariff_records.create!(:line_number=>1,:hts_1=>@hts)
      end
      @base_product = Product.new
    end
    it "should build tariff based on primary keys" do
      product_ids = @products.collect {|p| p.id}
      OpenChain::BulkUpdateClassification.build_common_classifications product_ids, @base_product
      @base_product.classifications.should have(1).item
      classification = @base_product.classifications.first
      classification.country.should == @country
      classification.should have(1).tariff_record
      tr = classification.tariff_records.first
      tr.hts_1.should == @hts
      tr.line_number.should == 1
    end
    it "should build tariff based on search run" do
      user = Factory(:user,:admin=>true,:company_id=>Factory(:company,:master=>true).id)
      search_setup = Factory(:search_setup,:module_type=>"Product",:user=>user)
      search_setup.touch #makes search_run
      OpenChain::BulkUpdateClassification.build_common_classifications search_setup.search_run, @base_product
      @base_product.classifications.should have(1).item
      classification = @base_product.classifications.first
      classification.country.should == @country
      classification.should have(1).tariff_record
      tr = classification.tariff_records.first
      tr.hts_1.should == @hts
      tr.line_number.should == 1
    end
    it "should build for one country and not for another when the second has different tariffs" do
      country_2 = Factory(:country)
      @products.each_with_index do |p,i|
        p.classifications.create!(:country_id=>country_2.id).tariff_records.create!(:line_number=>1,:hts_1=>"123456789#{i}")
      end
      product_ids = @products.collect {|p| p.id}
      OpenChain::BulkUpdateClassification.build_common_classifications product_ids, @base_product
      @base_product.classifications.should have(1).item
      classification = @base_product.classifications.first
      classification.country.should == @country
      classification.should have(1).tariff_record
      tr = classification.tariff_records.first
      tr.hts_1.should == @hts
      tr.line_number.should == 1
    end
    it "should not build if one of the products does not have the classification for the country" do
      country_2 = Factory(:country)
      @products.first.classifications.create!(:country_id=>country_2.id).tariff_records.create!(:line_number=>1,:hts_1=>"123456789")
      product_ids = @products.collect {|p| p.id}
      OpenChain::BulkUpdateClassification.build_common_classifications product_ids, @base_product
      @base_product.classifications.should have(1).item
      classification = @base_product.classifications.first
      classification.country.should == @country
      classification.should have(1).tariff_record
      tr = classification.tariff_records.first
      tr.hts_1.should == @hts
      tr.line_number.should == 1
    end
  end
end
