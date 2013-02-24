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
  end
end
