require 'spec_helper'

describe OpenChain::BulkUpdateClassification do
  describe "go" do
    before :each do
      ModelField.reload #cleanup from other tests
      @ms = MasterSetup.new :request_host => "localhost"
      MasterSetup.stub(:get).and_return @ms
      @u = Factory(:user,:company=>Factory(:company,:master=>true),:product_edit=>true,:classification_edit=>true)
      @p = Factory(:product)
      @country = Factory(:country)
      @h = {"pk"=>{ "1"=>@p.id.to_s },"product"=>{"classifications_attributes"=>{"0"=>{"country_id"=>@country.id.to_s}}}} 
      Product.any_instance.stub(:can_classify?).and_return true
    end
    it "should update an existing classification with primary keys" do
      m = OpenChain::BulkUpdateClassification.go(@h,@u)
      Product.find(@p.id).classifications.should have(1).item

      log = BulkProcessLog.first
      log.total_object_count.should eq 1
      log.changed_object_count.should eq 1
      log.change_records.should have(1).item
      log.change_records.first.failed.should be_false
      log.change_records.first.entity_snapshot.should_not be_nil

      @u.messages.length.should == 1
      @u.messages[0].subject.should == "Bulk Update Job Complete."
      @u.messages[0].body.should == "<p>Your classification job has completed.</p><p>1 Product saved.</p><p>The full update log is available <a href=\"https://#{@ms.request_host}/bulk_process_logs/#{log.id}\">here</a>.</p>"
      m[:message].should == "Bulk Update Job Complete."
      m[:errors].should == []
      m[:good_count].should == 1
    end
    it "should record validation errors in update log and messages" do
      # Create field validator rule to reject on 
      FieldValidatorRule.create! starts_with: "A", module_type: "Product", model_field_uid: "prod_uid"

      @h['product']['unique_identifier'] = 'BBB'
      m = OpenChain::BulkUpdateClassification.go(@h,@u)

      log = BulkProcessLog.first
      log.total_object_count.should eq 1
      log.changed_object_count.should eq 0
      log.change_records.should have(1).item
      log.change_records.first.failed.should be_true
      log.change_records.first.entity_snapshot.should be_nil
      log.change_records.first.messages[0].should match /^Error saving product/

      @u.messages.length.should == 1
      @u.messages[0].subject.should == "Bulk Update Job Complete (1 Error)."
      @u.messages[0].body.should == "<p>Your classification job has completed.</p><p>0 Products saved.</p><p>The full update log is available <a href=\"https://#{@ms.request_host}/bulk_process_logs/#{log.id}\">here</a>.</p>"
      m[:message].should == "Bulk Update Job Complete (1 Error)."
      m[:errors][0].should match /^Error saving product/
      m[:good_count].should == 0
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
    it "should allow override of product, classification & tariff custom values" do
      Factory(:official_tariff,:country=>@country,:hts_code=>'1234567890')
      class_cd = Factory(:custom_definition,:module_type=>'Classification',:data_type=>:string)
      tr_cd = Factory(:custom_definition,:module_type=>'TariffRecord',:data_type=>:string)
      prod_cd = Factory(:custom_definition,:module_type=>'Product',:data_type=>:string)

      tr = Factory(:tariff_record,:classification=>Factory(:classification,:country=>@country,:product=>@p))
      tr.update_custom_value! tr_cd, 'DEF'
      cls = tr.classification
      cls.update_custom_value! class_cd, 'ABC'
      @p.update_custom_value! prod_cd, "BLAH"

      @h['classification_custom'] = {'0'=>{'classification_cf'=>{class_cd.id.to_s => 'CLSOVR'}}} #blank classification shouldn't clear
      @h['tariff_custom'] = {'1' => {'tariffrecord_cf' => {tr_cd.id.to_s => 'TAROVR'}}}
      @h['product']['classifications_attributes']['0']['tariff_records_attributes'] = {'0'=>{'hts_1' => '1234567890','view_sequence'=>'1','line_number'=>'1'}}
      @h['product_cf'] = {prod_cd.id.to_s => "PRODCR"}

      OpenChain::BulkUpdateClassification.go(@h,@u)
      @p.reload
      @p.get_custom_value(prod_cd).value.should == "PRODCR"
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

  describe "quick_classify" do
    before :each do 
      @u = Factory(:user,:company=>Factory(:company,:master=>true),:product_edit=>true,:classification_edit=>true, :product_view=> true)
      @products = 2.times.collect {Factory(:product)}
      @country = Factory(:country, :iso_code => "US")
      @hts = '1234567890'
      @ms = MasterSetup.new :request_host => "localhost"
      MasterSetup.stub(:get).and_return @ms

      @parameters = {
        'pk' => ["#{@products[0].id}", "#{@products[1].id}"],
        'product' => {
            'classifications_attributes' => {
              "0" => {
                  'country_id' => "#{@country.id}",
                  'tariff_records_attributes' => {
                      "0" => {
                        "hts_1" => @hts
                      }
                  }
              }
            }
        }
      }
    end

    it "should create new classifications on products" do

      messages = OpenChain::BulkUpdateClassification.quick_classify @parameters, @u

      @products.each do |p|
        p.reload
        p.classifications.should have(1).item
        p.classifications[0].country_id.should eq @country.id

        p.classifications[0].tariff_records.should have(1).item
        p.classifications[0].tariff_records[0].hts_1.should eq @hts
      end

      log = BulkProcessLog.first
      log.change_records.should have(2).items
      log.change_records.each do |cr|
        cr.entity_snapshot.should_not be_nil
      end

      messages[:message].should eq "Bulk Classify Job Complete."
      messages[:errors].should have(0).items
      messages[:good_count].should eq 2

      @u.messages.should have(1).item
      @u.messages[0].subject.should eq "Bulk Classify Job Complete."
      @u.messages[0].body.should eq "<p>Your classification job has completed.</p><p>2 Products saved.</p><p>The full update log is available <a href=\"https://#{@ms.request_host}/bulk_process_logs/#{log.id}\">here</a>.</p>"
    end

    it "should create new classifications on products using json string" do
      OpenChain::BulkUpdateClassification.quick_classify @parameters.to_json, @u

      @products.each do |p|
        p.reload
        p.classifications.should have(1).item
        p.classifications[0].country_id.should eq @country.id

        p.classifications[0].tariff_records.should have(1).item
        p.classifications[0].tariff_records[0].hts_1.should eq @hts
      end
    end

    it "should update existing classification and tariff records on a product" do
      p = @products[0]
      p.classifications.create!(:country_id=>@country.id).tariff_records.create! hts_1: "75315678"

      @parameters['pk'] = ["#{@products[0].id}"]
      @parameters['product']['classifications_attributes']["0"]["id"] = "#{p.classifications[0].id}"
      @parameters['product']['classifications_attributes']["0"]["tariff_records_attributes"]["0"]["id"] = "#{p.classifications[0].tariff_records[0].id}"

      messages = OpenChain::BulkUpdateClassification.quick_classify @parameters, @u

      p.reload
      p.classifications.should have(1).item
      p.classifications[0].country_id.should eq @country.id

      p.classifications[0].tariff_records.should have(1).item
      p.classifications[0].tariff_records[0].hts_1.should eq @hts
    end

    it "should handle errors in product updates" do 
      # An easy way to force an error is to set the value to blank
      OpenChain::FieldLogicValidator.stub(:validate) do |o|
        o.errors[:base] << "Error"
        raise OpenChain::ValidationLogicError.new o
      end
      p = @products[0]
      @parameters['pk'] = ["#{@products[0].id}"]

      messages = OpenChain::BulkUpdateClassification.quick_classify @parameters, @u

      log = BulkProcessLog.first
      log.change_records.should have(1).item
      log.change_records.first.failed.should be_true
      log.change_records.first.messages[0].should eq "Error saving product #{p.unique_identifier}: Error"
      log.change_records.first.entity_snapshot.should be_nil

      @u.messages.should have(1).item
      @u.messages[0].subject.should eq "Bulk Classify Job Complete (1 Error)."
      @u.messages[0].body.should eq "<p>Your classification job has completed.</p><p>0 Products saved.</p><p>The full update log is available <a href=\"https://#{@ms.request_host}/bulk_process_logs/#{log.id}\">here</a>.</p>"

      messages[:message].should eq "Bulk Classify Job Complete (1 Error)."
      messages[:good_count].should eq 0
      messages[:errors].should have(1).item
      messages[:errors][0].should eq "Error saving product #{p.unique_identifier}: Error"
    end

    it "should verify user can classify product" do
      p = @products[0]
      @parameters['pk'] = ["#{@products[0].id}"]

      @u.update_attributes product_view: false
      messages = OpenChain::BulkUpdateClassification.quick_classify @parameters, @u

      @u.messages.should have(1).item
      @u.messages[0].subject.should eq "Bulk Classify Job Complete (1 Error)."

      messages[:message].should eq "Bulk Classify Job Complete (1 Error)."
      messages[:good_count].should eq 0
      messages[:errors].should have(1).item
      messages[:errors][0].should eq "You do not have permission to classify product #{p.unique_identifier}."
    end

    it "should not log user messages if specified" do
      p = @products[0]
      @parameters['pk'] = ["#{@products[0].id}"]

      @u.update_attributes product_view: false
      messages = OpenChain::BulkUpdateClassification.quick_classify @parameters, @u, no_user_message: true

      @u.messages.should have(0).items
    end
  end
end
