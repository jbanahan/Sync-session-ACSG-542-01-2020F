require 'spec_helper'

describe OpenChain::BulkUpdateClassification do
  describe "go" do
    before :each do
      ModelField.reload #cleanup from other tests
      @u = Factory(:user,:company=>Factory(:company,:master=>true),:product_edit=>true,:classification_edit=>true)
      @p = Factory(:product)
      @country = Factory(:country)
      @h = {"pk"=>{ "1"=>@p.id.to_s },"product"=>{"classifications_attributes"=>{"0"=>{"country_id"=>@country.id.to_s}}}} 
      Product.any_instance.stub(:can_classify?).and_return true
    end
    it "should update an existing classification with primary keys" do
      m = OpenChain::BulkUpdateClassification.go(@h,@u)
      Product.find(@p.id).classifications.should have(1).item
      @u.messages.length.should == 1
      @u.messages[0].subject.should == "Classification Job Complete."
      @u.messages[0].body.should == "<p>Your classification job has completed.</p><p>Products saved: 1</p><p>Messages:<br></p>"
      m[:message].should == "Classification Job Complete."
      m[:errors].should == []
      m[:good_count].should == 1
    end
    it "should update using serializable version of method" do
      OpenChain::BulkUpdateClassification.go_serializable(@h.to_json,@u.id)
      Product.find(@p.id).classifications.should have(1).item
    end
    it "should update but not make user messages" do
      OpenChain::BulkUpdateClassification.go(@h,@u, :no_user_message => true)
      Product.find(@p.id).classifications.should have(1).item
      @u.messages.length.should == 0
    end
    it "should maintain existing custom values for classification and tariff if not overridden" do
      Factory(:official_tariff,:country=>@country,:hts_code=>'1234567890')
      class_cd = Factory(:custom_definition,:module_type=>'Classification',:data_type=>:string)
      tr_cd = Factory(:custom_definition,:module_type=>'TariffRecord',:data_type=>:string)
      tr = Factory(:tariff_record,:classification=>Factory(:classification,:country=>@country,:product=>@p))
      tr.update_custom_value! tr_cd, 'DEF'
      cls = tr.classification
      cls.update_custom_value! class_cd, 'ABC'
      @h['classification_custom'] = {'0'=>{'classification_cf'=>{class_cd.id.to_s => ''}}} #blank classification shouldn't clear
      @h['tariff_custom'] = {'1' => {'tariffrecord_cf' => {tr_cd.id.to_s => ''}}} #black tariff shouldn't clear
      @h['product']['classifications_attributes']['0']['tariff_records_attributes'] = {'0'=>{'hts_1' => '1234567890'}}
      OpenChain::BulkUpdateClassification.go(@h,@u)
      @p.reload
      @p.classifications.first.tariff_records.first.hts_1.should == '1234567890'
      cls = @p.classifications.first
      cls.get_custom_value(class_cd).value.should == 'ABC'
      cls.tariff_records.first.get_custom_value(tr_cd).value.should == 'DEF'
    end
    it "should allow override of classification & tariff custom values" do
      Factory(:official_tariff,:country=>@country,:hts_code=>'1234567890')
      class_cd = Factory(:custom_definition,:module_type=>'Classification',:data_type=>:string)
      tr_cd = Factory(:custom_definition,:module_type=>'TariffRecord',:data_type=>:string)
      tr = Factory(:tariff_record,:classification=>Factory(:classification,:country=>@country,:product=>@p))
      tr.update_custom_value! tr_cd, 'DEF'
      cls = tr.classification
      cls.update_custom_value! class_cd, 'ABC'
      @h['classification_custom'] = {'0'=>{'classification_cf'=>{class_cd.id.to_s => 'CLSOVR'}}} #blank classification shouldn't clear
      @h['tariff_custom'] = {'1' => {'tariffrecord_cf' => {tr_cd.id.to_s => 'TAROVR'}}}
      @h['product']['classifications_attributes']['0']['tariff_records_attributes'] = {'0'=>{'hts_1' => '1234567890','view_sequence'=>'1','line_number'=>'1'}}
      OpenChain::BulkUpdateClassification.go(@h,@u)
      @p.reload
      @p.classifications.first.tariff_records.first.hts_1.should == '1234567890'
      cls = @p.classifications.first
      cls.get_custom_value(class_cd).value.should == 'CLSOVR'
      cls.tariff_records.first.get_custom_value(tr_cd).value.should == 'TAROVR'
    end
  end
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
      OpenChain::BulkUpdateClassification.build_common_classifications search_setup.search_runs.first, @base_product
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
