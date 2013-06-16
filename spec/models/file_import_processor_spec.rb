require 'spec_helper'

describe FileImportProcessor do
  it 'should initialize without search setup' do
    imp = Factory(:imported_file)
    imp.search_setup_id.should be_nil #factory shouldn't create this
    lambda { FileImportProcessor.new(imp,'a,b') }.should_not raise_error
  end
  it 'should initialize with bad search_setup_id' do
    imp = Factory(:imported_file,:search_setup_id=>9999)
    imp.search_setup.should be_nil #id should not match to anything
    lambda { FileImportProcessor.new(imp,'a,b') }.should_not raise_error
  end
  
  describe :preview do
    it "should not write to DB" do
      @ss = SearchSetup.new(:module_type=>"Product")
      @f = ImportedFile.new(:search_setup=>@ss,:module_type=>"Product",:starting_column=>0) 
      country = Factory(:country)
      pro = FileImportProcessor.new(@f,nil,[FileImportProcessor::PreviewListener.new])
      pro.stub(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid",:rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name",:rank=>2),
        SearchColumn.new(:model_field_uid=>"class_cntry_iso",:rank=>3)
      ])
      pro.stub(:get_rows).and_yield ['abc-123','pn',country.iso_code]
      r = pro.preview_file
      r.should have(3).rows
      Product.count.should == 0
    end
  end

  describe :do_row do
    before :each do
      @ss = SearchSetup.new(:module_type=>"Product")
      @f = ImportedFile.new(:search_setup=>@ss,:module_type=>"Product") 
    end
    it "should save row" do
      pro = FileImportProcessor.new(@f,nil,[])
      pro.stub(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid",:rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name",:rank=>2)
      ])
      pro.do_row 0, ['uid-abc','name'], true, -1
      Product.find_by_unique_identifier('uid-abc').name.should == 'name'
    end
    it "should create children" do
      country = Factory(:country)
      ot = Factory(:official_tariff,:hts_code=>'1234567890',:country=>country)
      pro = FileImportProcessor.new(@f,nil,[])
      pro.stub(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid",:rank=>1),
        SearchColumn.new(:model_field_uid=>"class_cntry_iso",:rank=>2),
        SearchColumn.new(:model_field_uid=>"hts_line_number",:rank=>3),
        SearchColumn.new(:model_field_uid=>"hts_hts_1",:rank=>4)
      ])
      pro.do_row 0, ['uid-abc',country.iso_code,1,'1234567890'], true, -1
      p = Product.find_by_unique_identifier('uid-abc')
      p.should have(1).classifications
      cl = p.classifications.first
      cl.country.should == country
      cl.should have(1).tariff_records
      tr = cl.tariff_records.first
      tr.hts_1.should == '1234567890'
    end
    it "should update row" do
      p = Factory(:product,unique_identifier:'uid-abc')
      pro = FileImportProcessor.new(@f,nil,[])
      pro.stub(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid",:rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name",:rank=>2)
      ])
      pro.do_row 0, ['uid-abc','name'], true, -1
      p.reload
      p.name.should == 'name'
    end
    it "should set custom values" do
      cd = Factory(:custom_definition,:module_type=>"Product",:data_type=>"string")
      pro = FileImportProcessor.new(@f,nil,[])
      pro.stub(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid",:rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name",:rank=>2),
        SearchColumn.new(:model_field_uid=>"*cf_#{cd.id}",:rank=>3)
      ])
      pro.do_row 0, ['uid-abc','name','cval'], true, -1
      Product.find_by_unique_identifier('uid-abc').get_custom_value(cd).value.should == 'cval'
    end
    it "should not set read only custom values" do
      cd = Factory(:custom_definition,:read_only=>true,:module_type=>"Product",:data_type=>"string")
      pro = FileImportProcessor.new(@f,nil,[])
      pro.stub(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid",:rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name",:rank=>2),
        SearchColumn.new(:model_field_uid=>"*cf_#{cd.id}",:rank=>3)
      ])
      pro.do_row 0, ['uid-abc','name','cval'], true, -1
      Product.find_by_unique_identifier('uid-abc').get_custom_value(cd).value.should be_blank
    end
    context 'special cases' do
      it "should set country classification from product level fields" do
        c = Factory(:country,:import_location=>true)
        ModelField.reload
        pro = FileImportProcessor.new(@f,nil,[])
        pro.stub(:get_columns).and_return([
          SearchColumn.new(:model_field_uid=>"prod_uid",:rank=>1),
          SearchColumn.new(:model_field_uid=>"*fhts_1_#{c.id}",:rank=>2)
        ])
        pro.do_row 0, ['uid-abc','1234.56.7890'], true, -1
        Product.count.should == 1
        p = Product.find_by_unique_identifier 'uid-abc'
        p.should have(1).classification
        p.classifications.where(:country_id=>c.id).first.tariff_records.first.hts_1.should == '1234567890'
      end
      it "should set country classification from product level for existing product" do
        Factory(:product,unique_identifier:'uid-abc')
        c = Factory(:country,:import_location=>true)
        ModelField.reload
        pro = FileImportProcessor.new(@f,nil,[])
        pro.stub(:get_columns).and_return([
          SearchColumn.new(:model_field_uid=>"prod_uid",:rank=>1),
          SearchColumn.new(:model_field_uid=>"*fhts_1_#{c.id}",:rank=>2)
        ])
        pro.do_row 0, ['uid-abc','1234.56.7890'], true, -1
        Product.count.should == 1
        p = Product.find_by_unique_identifier 'uid-abc'
        p.should have(1).classification
        p.classifications.where(:country_id=>c.id).first.tariff_records.first.hts_1.should == '1234567890'
      end
    end
  end
end
