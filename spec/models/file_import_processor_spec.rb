require 'spec_helper'
require 'file_import_processor'

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

    it "should return a SpreadsheetImportProcessor for xls and xlsx files" do
      @ss = SearchSetup.new(:module_type=>"Product")
      @f = ImportedFile.new(:search_setup=>@ss,:module_type=>"Product",:starting_column=>0, attached_file_name: "file.xlsx") 
      country = Factory(:country)
      pro = FileImportProcessor.new(@f,nil,[FileImportProcessor::PreviewListener.new])
      (FileImportProcessor.find_processor(@f)).should be_an_instance_of(FileImportProcessor::SpreadsheetImportProcessor)
    end

  end

  describe :do_row do
    before :each do
      @ss = SearchSetup.new(:module_type=>"Product")
      @f = ImportedFile.new(:search_setup=>@ss,:module_type=>"Product") 
      @u = User.new
    end
    it "should save row" do
      pro = FileImportProcessor.new(@f,nil,[])
      pro.stub(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid",:rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name",:rank=>2)
      ])
      pro.do_row 0, ['uid-abc','name'], true, -1, @u
      Product.find_by_unique_identifier('uid-abc').name.should == 'name'
    end
    it "should not set blank values" do
      p = Factory(:product,unique_identifier:'uid-abc',name:'name')
      pro = FileImportProcessor.new(@f,nil,[])
      pro.stub(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid",:rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name",:rank=>2)
      ])
      pro.do_row 0, ['uid-abc','  '], true, -1, @u
      Product.find_by_unique_identifier('uid-abc').name.should == 'name'
    end
    it "should set boolean false values" do
      p = Factory(:product,unique_identifier:'uid-abc',name:'name')
      pro = FileImportProcessor.new(@f,nil,[])
      pro.stub(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid",:rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name",:rank=>2)
      ])
      pro.do_row 0, ['uid-abc', false], true, -1, @u
      # False values, when put in string fields, turn to 0 via rails type coercion
      Product.find_by_unique_identifier('uid-abc').name.should == '0'
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
      pro.do_row 0, ['uid-abc',country.iso_code,1,'1234567890'], true, -1, @u
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
      pro.do_row 0, ['uid-abc','name'], true, -1, @u
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
      pro.do_row 0, ['uid-abc','name','cval'], true, -1, @u
      Product.find_by_unique_identifier('uid-abc').get_custom_value(cd).value.should == 'cval'
    end
    it "should set boolean custom values" do
      cd = Factory(:custom_definition,:module_type=>"Product",:data_type=>"boolean")
      pro = FileImportProcessor.new(@f,nil,[])
      pro.stub(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid",:rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name",:rank=>2),
        SearchColumn.new(:model_field_uid=>"*cf_#{cd.id}",:rank=>3)
      ])
      pro.do_row 0, ['uid-abc','name',true], true, -1, @u
      expect(Product.find_by_unique_identifier('uid-abc').get_custom_value(cd).value).to be_true
    end
    it "should set boolean false custom values" do
      cd = Factory(:custom_definition,:module_type=>"Product",:data_type=>"boolean")
      pro = FileImportProcessor.new(@f,nil,[])
      pro.stub(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid",:rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name",:rank=>2),
        SearchColumn.new(:model_field_uid=>"*cf_#{cd.id}",:rank=>3)
      ])
      pro.do_row 0, ['uid-abc','name', false], true, -1, @u
      expect(Product.find_by_unique_identifier('uid-abc').get_custom_value(cd).value).to be_false
    end
    it "should set boolean custom value to true w/ text of '1'" do
      cd = Factory(:custom_definition,:module_type=>"Product",:data_type=>"boolean")
      pro = FileImportProcessor.new(@f,nil,[])
      pro.stub(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid",:rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name",:rank=>2),
        SearchColumn.new(:model_field_uid=>"*cf_#{cd.id}",:rank=>3)
      ])
      pro.do_row 0, ['uid-abc','name', "1"], true, -1, @u
      expect(Product.find_by_unique_identifier('uid-abc').get_custom_value(cd).value).to eq true
    end
    it "should set boolean custom value to false w/ text of '0'" do
      cd = Factory(:custom_definition,:module_type=>"Product",:data_type=>"boolean")
      pro = FileImportProcessor.new(@f,nil,[])
      pro.stub(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid",:rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name",:rank=>2),
        SearchColumn.new(:model_field_uid=>"*cf_#{cd.id}",:rank=>3)
      ])
      pro.do_row 0, ['uid-abc','name', "0"], true, -1, @u
      expect(Product.find_by_unique_identifier('uid-abc').get_custom_value(cd).value).to eq false
    end
    it "should not unset boolean custom values when nil value is present" do
      prod = Factory(:product, unique_identifier: 'uid-abc')
      cd = Factory(:custom_definition,:module_type=>"Product",:data_type=>"boolean")
      prod.update_custom_value! cd, true

      pro = FileImportProcessor.new(@f,nil,[])
      pro.stub(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid",:rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name",:rank=>2),
        SearchColumn.new(:model_field_uid=>"*cf_#{cd.id}",:rank=>3)
      ])
      pro.do_row 0, ['uid-abc','name', nil], true, -1, @u
      expect(Product.find_by_unique_identifier('uid-abc').get_custom_value(cd).value).to be_true
    end
    it "should not set read only custom values" do
      cd = Factory(:custom_definition,:module_type=>"Product",:data_type=>"string")
      FieldValidatorRule.create!(:model_field_uid=>"*cf_#{cd.id}",:custom_definition_id=>cd.id,:read_only=>true)
      pro = FileImportProcessor.new(@f,nil,[])
      pro.stub(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid",:rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name",:rank=>2),
        SearchColumn.new(:model_field_uid=>"*cf_#{cd.id}",:rank=>3)
      ])
      pro.do_row 0, ['uid-abc','name','cval'], true, -1, User.new
      Product.find_by_unique_identifier('uid-abc').get_custom_value(cd).value.should be_blank
    end
    it "should error when user doesn't have permission" do
      cd = Factory(:custom_definition,:module_type=>"Product",:data_type=>"string")
      FieldValidatorRule.create!(model_field_uid: "*cf_#{cd.id}",custom_definition_id: cd.id, can_edit_groups: "GROUP")
      pro = FileImportProcessor.new(@f,nil,[])
      pro.stub(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid",:rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name",:rank=>2),
        SearchColumn.new(:model_field_uid=>"*cf_#{cd.id}",:rank=>3)
      ])
      pro.should_receive(:fire_row).with(anything, anything, include("ERROR: You do not have permission to edit #{cd.label}."), anything)
      pro.do_row 0, ['uid-abc','name','cval'], true, -1, User.new
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
        pro.do_row 0, ['uid-abc','1234.56.7890'], true, -1, @u
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
        pro.do_row 0, ['uid-abc','1234.56.7890'], true, -1, @u
        Product.count.should == 1
        p = Product.find_by_unique_identifier 'uid-abc'
        p.should have(1).classification
        p.classifications.where(:country_id=>c.id).first.tariff_records.first.hts_1.should == '1234567890'
      end
      it "should convert Float and BigDecimal values to string, trimming off trailing decimal point and zero" do
        # The product set here recreates the issue we saw with the import we're trying to resolve
        # However, the MySQL version (or configuration) on our dev machines sort of handles a 
        # translation of 'where unique_identifier = 1.0' casting a string value of '1' to 1.0 
        # (albeit with warnings for any unique id that couldn't be cast)
        # whereas our current production version does not do an implicit cast...so we're not getting an exact 
        # test scenario.  However, as long as we test that the unique identifier value isn't 
        # 1.0 after the update and that we did update the existing record then we should be good.
        p = Product.create! unique_identifier: "1", name: "ABC"

        pro = FileImportProcessor.new(@f,nil,[])
        pro.stub(:get_columns).and_return([
          SearchColumn.new(:model_field_uid=>"prod_uid",:rank=>1),
          SearchColumn.new(:model_field_uid=>"prod_name",:rank=>2),
          SearchColumn.new(:model_field_uid=>"prod_uom",:rank=>3)
        ])
        pro.do_row 0, [1.0,2.0, BigDecimal("3.0")], true, -1, @u
        delta_p = Product.find_by_unique_identifier('1')
        delta_p.should_not be_nil
        delta_p.id.should == p.id
        delta_p.name.should == "2"
        delta_p.unit_of_measure.should == "3"
      end
      it "should convert Float and BigDecimal values to string, retaining decimal point values" do
        pro = FileImportProcessor.new(@f,nil,[])
        pro.stub(:get_columns).and_return([
          SearchColumn.new(:model_field_uid=>"prod_uid",:rank=>1),
          SearchColumn.new(:model_field_uid=>"prod_name",:rank=>2),
          SearchColumn.new(:model_field_uid=>"prod_uom",:rank=>3)
        ])
        pro.do_row 0, [1,2.1, BigDecimal("3.10")], true, -1, @u
        p = Product.find_by_unique_identifier('1')
        p.name.should == "2.1"
        p.unit_of_measure.should == "3.1"
      end
      it "should NOT convert numbers for numeric fields" do
        ss = SearchSetup.new(:module_type=>"Entry")
        f = ImportedFile.new(:search_setup=>ss,:module_type=>"Entry") 

        pro = FileImportProcessor.new(f,nil,[])
        pro.stub(:get_columns).and_return([
          SearchColumn.new(:model_field_uid=>"ent_brok_ref",:rank=>1),
          SearchColumn.new(:model_field_uid=>"ent_total_packages",:rank=>2)
        ])
        pro.do_row 0, [1,2.0], true, -1, @u
        e = Entry.where(:broker_reference => "1").first
        e.total_packages.should == 2
      end

      context "error cases" do
        before :each do 
          @listener = Class.new do 
            attr_reader :messages, :failed
            def process_row row_number, object, m, failed
              @messages = m
              @failed = failed
            end
          end.new
        end

        it "errors on invalid HTS values for First HTS fields" do
          c = Factory(:country,:import_location=>true)
          OfficialTariff.create! country: c, hts_code: "9876543210"

          ModelField.reload        
          pro = FileImportProcessor.new(@f,nil,[@listener])
          pro.stub(:get_columns).and_return([
            SearchColumn.new(:model_field_uid=>"prod_uid",:rank=>1),
            SearchColumn.new(:model_field_uid=>"*fhts_1_#{c.id}",:rank=>2)
          ])
          pro.do_row 0, ['uid-abc','1234.56.7890'], true, -1, @u

          Product.count.should == 0
          expect(@listener.failed).to be_true
          expect(@listener.messages).to include("ERROR: 1234.56.7890 is not valid for #{c.iso_code} HTS 1")
        end

        it "informs user of missing key fields" do
          pro = FileImportProcessor.new(@f,nil,[@listener])
          pro.stub(:get_columns).and_return([
            SearchColumn.new(:model_field_uid=>"prod_name",:rank=>1)
          ])
          FileImportProcessor::MissingCoreModuleFieldError.any_instance.should_not_receive(:log_me)
          expect {pro.do_row 0, ['name'], true, -1, @u}.to raise_error "Cannot load Product data without a value in the 'Unique Identifier' field."
        end

        it "informs user of missing compound key fields" do
          c = Factory(:country,:import_location=>true)
          OfficialTariff.create! country: c, hts_code: "9876543210"

          ModelField.reload        
          pro = FileImportProcessor.new(@f,nil,[@listener])
          pro.stub(:get_columns).and_return([
            SearchColumn.new(:model_field_uid=>"prod_uid",:rank=>1),
            SearchColumn.new(:model_field_uid=>"hts_hts_1",:rank=>2)
          ])

          FileImportProcessor::MissingCoreModuleFieldError.any_instance.should_not_receive(:log_me)
          expect {pro.do_row 0, ['uid-abc','1234.56.7890'], true, -1, @u}.to raise_error "Cannot load Classification data without a value in one of the 'Country Name' or 'Country ISO Code' fields."
        end
      end
      
    end
  end

  describe "process_file" do 
    context "CSVImportProcessor" do
      it "skips blank lines in CSV files" do
        f = ImportedFile.new(:module_type=>"Product",:starting_row=>0, attached_file_name: "file.xlsx")
        p = FileImportProcessor::CSVImportProcessor.new f, "a,b\n,,,\nc,d\n, , , ,,\n,,,,,\n\n", []
        rows = []
        p.get_rows {|r| rows << r}
        expect(rows).to eq [["a", "b"], ["c", "d"]]
      end
    end
  end
end
