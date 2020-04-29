describe FileImportProcessor do
  it 'should initialize without search setup' do
    imp = Factory(:imported_file)
    expect(imp.search_setup_id).to be_nil # factory shouldn't create this
    expect { FileImportProcessor.new(imp, 'a,b') }.not_to raise_error
  end
  it 'should initialize with bad search_setup_id' do
    imp = Factory(:imported_file, :search_setup_id=>9999)
    expect(imp.search_setup).to be_nil # id should not match to anything
    expect { FileImportProcessor.new(imp, 'a,b') }.not_to raise_error
  end

  describe "preview" do
    it "should not write to DB" do
      @ss = SearchSetup.new(:module_type=>"Product")
      @f = ImportedFile.new(:search_setup=>@ss, :module_type=>"Product", :starting_column=>0)
      country = Factory(:country)
      pro = FileImportProcessor::CSVImportProcessor.new(@f, nil, [FileImportProcessor::PreviewListener.new])
      allow(pro).to receive(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid", :rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name", :rank=>2),
        SearchColumn.new(:model_field_uid=>"class_cntry_iso", :rank=>3)
      ])
      allow(pro).to receive(:get_rows).with(preview: true).and_yield ['abc-123', 'pn', country.iso_code]
      r = pro.preview_file
      expect(r.size).to eq(3)
      expect(Product.count).to eq(0)
    end

    it "should return a SpreadsheetImportProcessor for xls and xlsx files" do
      @ss = SearchSetup.new(:module_type=>"Product")
      @f = ImportedFile.new(:search_setup=>@ss, :module_type=>"Product", :starting_column=>0, attached_file_name: "file.xlsx")
      country = Factory(:country)
      pro = FileImportProcessor.new(@f, nil, [FileImportProcessor::PreviewListener.new])
      expect(FileImportProcessor.find_processor(@f)).to be_an_instance_of(FileImportProcessor::SpreadsheetImportProcessor)
    end

  end

  describe "do_row" do
    before :each do
      @ss = SearchSetup.new(:module_type=>"Product")
      @f = ImportedFile.new(:search_setup=>@ss, :module_type=>"Product")
      @u = User.new
    end
    it "should save row" do
      pro = FileImportProcessor.new(@f, nil, [])
      allow(pro).to receive(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid", :rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name", :rank=>2)
      ])
      # removes whitespace
      pro.do_row 0, ["\tuid-abc ", "name"], true, -1, @u
      expect(Product.find_by(unique_identifier: 'uid-abc').name).to eq('name')
    end
    it "should not set blank values" do
      p = Factory(:product, unique_identifier:'uid-abc', name:'name')
      pro = FileImportProcessor.new(@f, nil, [])
      allow(pro).to receive(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid", :rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name", :rank=>2)
      ])
      pro.do_row 0, ['uid-abc', '  '], true, -1, @u
      expect(Product.find_by(unique_identifier: 'uid-abc').name).to eq('name')
    end
    it "should set boolean false values" do
      p = Factory(:product, unique_identifier:'uid-abc', name:'name')
      pro = FileImportProcessor.new(@f, nil, [])
      allow(pro).to receive(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid", :rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name", :rank=>2)
      ])
      pro.do_row 0, ['uid-abc', false], true, -1, @u
      # False values, when put in string fields, turn to 0 via rails type coercion
      expect(Product.find_by(unique_identifier: 'uid-abc').name).to eq('0')
    end
    it "should create children" do
      country = Factory(:country)
      ot = Factory(:official_tariff, :hts_code=>'1234567890', :country=>country)
      pro = FileImportProcessor.new(@f, nil, [])
      allow(pro).to receive(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid", :rank=>1),
        SearchColumn.new(:model_field_uid=>"class_cntry_iso", :rank=>2),
        SearchColumn.new(:model_field_uid=>"hts_line_number", :rank=>3),
        SearchColumn.new(:model_field_uid=>"hts_hts_1", :rank=>4)
      ])
      pro.do_row 0, ['uid-abc', country.iso_code, 1, '1234567890'], true, -1, @u
      p = Product.find_by(unique_identifier: 'uid-abc')
      expect(p.classifications.size).to eq(1)
      cl = p.classifications.first
      expect(cl.country).to eq(country)
      expect(cl.tariff_records.size).to eq(1)
      tr = cl.tariff_records.first
      expect(tr.hts_1).to eq('1234567890')
    end
    it "should update row" do
      p = Factory(:product, unique_identifier:'uid-abc')
      pro = FileImportProcessor.new(@f, nil, [])
      allow(pro).to receive(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid", :rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name", :rank=>2)
      ])
      pro.do_row 0, ['uid-abc', 'name'], true, -1, @u
      p.reload
      expect(p.name).to eq('name')
    end
    it "should set custom values" do
      cd = Factory(:custom_definition, :module_type=>"Product", :data_type=>"string")
      pro = FileImportProcessor.new(@f, nil, [])
      allow(pro).to receive(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid", :rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name", :rank=>2),
        SearchColumn.new(:model_field_uid=>"*cf_#{cd.id}", :rank=>3)
      ])
      pro.do_row 0, ['uid-abc', 'name', 'cval'], true, -1, @u
      expect(Product.find_by(unique_identifier: 'uid-abc').get_custom_value(cd).value).to eq('cval')
    end
    it "should set boolean custom values" do
      cd = Factory(:custom_definition, :module_type=>"Product", :data_type=>"boolean")
      pro = FileImportProcessor.new(@f, nil, [])
      allow(pro).to receive(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid", :rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name", :rank=>2),
        SearchColumn.new(:model_field_uid=>"*cf_#{cd.id}", :rank=>3)
      ])
      pro.do_row 0, ['uid-abc', 'name', true], true, -1, @u
      expect(Product.find_by(unique_identifier: 'uid-abc').get_custom_value(cd).value).to be_truthy
    end
    it "should set boolean false custom values" do
      cd = Factory(:custom_definition, :module_type=>"Product", :data_type=>"boolean")
      pro = FileImportProcessor.new(@f, nil, [])
      allow(pro).to receive(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid", :rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name", :rank=>2),
        SearchColumn.new(:model_field_uid=>"*cf_#{cd.id}", :rank=>3)
      ])
      pro.do_row 0, ['uid-abc', 'name', false], true, -1, @u
      expect(Product.find_by(unique_identifier: 'uid-abc').get_custom_value(cd).value).to be_falsey
    end
    it "should set boolean custom value to true w/ text of '1'" do
      cd = Factory(:custom_definition, :module_type=>"Product", :data_type=>"boolean")
      pro = FileImportProcessor.new(@f, nil, [])
      allow(pro).to receive(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid", :rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name", :rank=>2),
        SearchColumn.new(:model_field_uid=>"*cf_#{cd.id}", :rank=>3)
      ])
      pro.do_row 0, ['uid-abc', 'name', "1"], true, -1, @u
      expect(Product.find_by(unique_identifier: 'uid-abc').get_custom_value(cd).value).to eq true
    end
    it "should set boolean custom value to false w/ text of '0'" do
      cd = Factory(:custom_definition, :module_type=>"Product", :data_type=>"boolean")
      pro = FileImportProcessor.new(@f, nil, [])
      allow(pro).to receive(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid", :rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name", :rank=>2),
        SearchColumn.new(:model_field_uid=>"*cf_#{cd.id}", :rank=>3)
      ])
      pro.do_row 0, ['uid-abc', 'name', "0"], true, -1, @u
      expect(Product.find_by(unique_identifier: 'uid-abc').get_custom_value(cd).value).to eq false
    end
    it "should not unset boolean custom values when nil value is present" do
      prod = Factory(:product, unique_identifier: 'uid-abc')
      cd = Factory(:custom_definition, :module_type=>"Product", :data_type=>"boolean")
      prod.update_custom_value! cd, true

      pro = FileImportProcessor.new(@f, nil, [])
      allow(pro).to receive(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid", :rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name", :rank=>2),
        SearchColumn.new(:model_field_uid=>"*cf_#{cd.id}", :rank=>3)
      ])
      pro.do_row 0, ['uid-abc', 'name', nil], true, -1, @u
      expect(Product.find_by(unique_identifier: 'uid-abc').get_custom_value(cd).value).to be_truthy
    end
    it "should not set read only custom values" do
      cd = Factory(:custom_definition, :module_type=>"Product", :data_type=>"string")
      FieldValidatorRule.create!(:model_field_uid=>"*cf_#{cd.id}", :custom_definition_id=>cd.id, :read_only=>true)
      pro = FileImportProcessor.new(@f, nil, [])
      allow(pro).to receive(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid", :rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name", :rank=>2),
        SearchColumn.new(:model_field_uid=>"*cf_#{cd.id}", :rank=>3)
      ])
      pro.do_row 0, ['uid-abc', 'name', 'cval'], true, -1, User.new
      expect(Product.find_by(unique_identifier: 'uid-abc').get_custom_value(cd).value).to be_blank
    end
    it "should error when user doesn't have permission" do
      cd = Factory(:custom_definition, :module_type=>"Product", :data_type=>"string")
      FieldValidatorRule.create!(model_field_uid: "*cf_#{cd.id}", custom_definition_id: cd.id, can_edit_groups: "GROUP")
      pro = FileImportProcessor.new(@f, nil, [])
      allow(pro).to receive(:get_columns).and_return([
        SearchColumn.new(:model_field_uid=>"prod_uid", :rank=>1),
        SearchColumn.new(:model_field_uid=>"prod_name", :rank=>2),
        SearchColumn.new(:model_field_uid=>"*cf_#{cd.id}", :rank=>3)
      ])
      expect(pro).to receive(:fire_row).with(anything, anything, include("ERROR: You do not have permission to edit #{cd.label}."), anything)
      pro.do_row 0, ['uid-abc', 'name', 'cval'], true, -1, User.new
    end
    context 'special cases' do
      it "should set country classification from product level fields" do
        c = Factory(:country, :import_location=>true)
        ModelField.reload
        pro = FileImportProcessor.new(@f, nil, [])
        allow(pro).to receive(:get_columns).and_return([
          SearchColumn.new(:model_field_uid=>"prod_uid", :rank=>1),
          SearchColumn.new(:model_field_uid=>"*fhts_1_#{c.id}", :rank=>2)
        ])
        pro.do_row 0, ['uid-abc', '1234.56.7890'], true, -1, @u
        expect(Product.count).to eq(1)
        p = Product.find_by(unique_identifier: 'uid-abc')
        expect(p.classifications.size).to eq(1)
        expect(p.classifications.where(:country_id=>c.id).first.tariff_records.first.hts_1).to eq('1234567890')
      end
      it "should set country classification from product level for existing product" do
        Factory(:product, unique_identifier:'uid-abc')
        c = Factory(:country, :import_location=>true)
        ModelField.reload
        pro = FileImportProcessor.new(@f, nil, [])
        allow(pro).to receive(:get_columns).and_return([
          SearchColumn.new(:model_field_uid=>"prod_uid", :rank=>1),
          SearchColumn.new(:model_field_uid=>"*fhts_1_#{c.id}", :rank=>2)
        ])
        pro.do_row 0, ['uid-abc', '1234.56.7890'], true, -1, @u
        expect(Product.count).to eq(1)
        p = Product.find_by(unique_identifier: 'uid-abc')
        expect(p.classifications.size).to eq(1)
        expect(p.classifications.where(:country_id=>c.id).first.tariff_records.first.hts_1).to eq('1234567890')
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

        pro = FileImportProcessor.new(@f, nil, [])
        allow(pro).to receive(:get_columns).and_return([
          SearchColumn.new(:model_field_uid=>"prod_uid", :rank=>1),
          SearchColumn.new(:model_field_uid=>"prod_name", :rank=>2),
          SearchColumn.new(:model_field_uid=>"prod_uom", :rank=>3)
        ])
        pro.do_row 0, [1.0, 2.0, BigDecimal("3.0")], true, -1, @u
        delta_p = Product.find_by(unique_identifier: '1')
        expect(delta_p).not_to be_nil
        expect(delta_p.id).to eq(p.id)
        expect(delta_p.name).to eq("2")
        expect(delta_p.unit_of_measure).to eq("3")
      end
      it "should convert Float and BigDecimal values to string, retaining decimal point values" do
        pro = FileImportProcessor.new(@f, nil, [])
        allow(pro).to receive(:get_columns).and_return([
          SearchColumn.new(:model_field_uid=>"prod_uid", :rank=>1),
          SearchColumn.new(:model_field_uid=>"prod_name", :rank=>2),
          SearchColumn.new(:model_field_uid=>"prod_uom", :rank=>3)
        ])
        pro.do_row 0, [1, 2.1, BigDecimal("3.10")], true, -1, @u
        p = Product.find_by(unique_identifier: '1')
        expect(p.name).to eq("2.1")
        expect(p.unit_of_measure).to eq("3.1")
      end
      it "should NOT convert numbers for numeric fields" do
        ss = SearchSetup.new(:module_type=>"Entry")
        f = ImportedFile.new(:search_setup=>ss, :module_type=>"Entry")

        pro = FileImportProcessor.new(f, nil, [])
        allow(pro).to receive(:get_columns).and_return([
          SearchColumn.new(:model_field_uid=>"ent_brok_ref", :rank=>1),
          SearchColumn.new(:model_field_uid=>"ent_total_packages", :rank=>2)
        ])
        pro.do_row 0, [1, 2.0], true, -1, @u
        e = Entry.where(:broker_reference => "1").first
        expect(e.total_packages).to eq(2)
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
          c = Factory(:country, :import_location=>true)
          OfficialTariff.create! country: c, hts_code: "9876543210"

          ModelField.reload
          pro = FileImportProcessor.new(@f, nil, [@listener])
          allow(pro).to receive(:get_columns).and_return([
            SearchColumn.new(:model_field_uid=>"prod_uid", :rank=>1),
            SearchColumn.new(:model_field_uid=>"*fhts_1_#{c.id}", :rank=>2)
          ])
          pro.do_row 0, ['uid-abc', '1234.56.7890'], true, -1, @u

          expect(Product.count).to eq(0)
          expect(@listener.failed).to be_truthy
          expect(@listener.messages).to include("ERROR: 1234.56.7890 is not valid for #{c.iso_code} HTS 1")
        end

        it "informs user of missing key fields" do
          pro = FileImportProcessor.new(@f, nil, [@listener])
          allow(pro).to receive(:get_columns).and_return([
            SearchColumn.new(:model_field_uid=>"prod_name", :rank=>1)
          ])
          expect {
            pro.do_row 0, ['name'], true, -1, @u
          }.to_not change(ErrorLogEntry, :count)
          expect(@listener.failed).to be_truthy
          expect(@listener.messages).to include("ERROR: Cannot load Product data without a value in the 'Unique Identifier' field.")
        end

        it "informs user of missing compound key fields" do
          c = Factory(:country, :import_location=>true)
          OfficialTariff.create! country: c, hts_code: "9876543210"

          ModelField.reload
          pro = FileImportProcessor.new(@f, nil, [@listener])
          allow(pro).to receive(:get_columns).and_return([
            SearchColumn.new(:model_field_uid=>"prod_uid", :rank=>1),
            SearchColumn.new(:model_field_uid=>"hts_hts_1", :rank=>2)
          ])

          expect {
            pro.do_row 0, ['uid-abc', '1234.56.7890'], true, -1, @u
          }.to_not change(ErrorLogEntry, :count)
          expect(@listener.failed).to be_truthy
          expect(@listener.messages).to include("ERROR: Cannot load Classification data without a value in one of the 'Country Name' or 'Country ISO Code' fields.")
        end
      end
    end
  end

  describe "CSVImportProcessor" do
    let (:search_setup) { instance_double(SearchSetup) }
    let (:imported_file) {
      f = instance_double(ImportedFile)
      allow(f).to receive(:search_setup).and_return search_setup
      allow(f).to receive(:module_type).and_return "Product"
      expect(f).to receive(:starting_row).and_return 1
      f
    }
    let (:data) { "\n,,,,\na,b\n,,,\nc,d\n, , , ,,\n,,,,,\n\n" }
    subject { FileImportProcessor::CSVImportProcessor.new imported_file, data }

    describe "get_rows" do
      it "skips blank lines in CSV files" do
        rows = []
        subject.get_rows {|r| rows << r}
        expect(rows).to eq [["a", "b"], ["c", "d"]]
      end

      it "converts from Windows-1252 if 'invalid byte sequence' is found" do
        data.clear
        data << "a,\x80\nc,d\n"
        rows = []
        subject.get_rows {|r| rows << r}
        expect(rows).to eq [["a", "€"], ["c", "d"]]
      end

      it "doesn't rescue non-encoding exceptions" do
        expect(subject).to receive(:utf_8_parse).and_raise("some other kind of problem")
        expect(subject).not_to receive(:windows_1252_parse)
        expect { subject.get_rows {|r| rows << r} }.to raise_error("some other kind of problem")
      end

      it "only parses the first line for previews" do
        rows = []
        subject.get_rows(preview: true) {|r| rows << r}
        expect(rows).to eq [["a", "b"]]
      end

      it "only parses the first line for previews with windows encodings" do
        data.clear
        data << "a,\x80\nc,d\n"
        rows = []
        subject.get_rows(preview: true) {|r| rows << r}
        expect(rows).to eq [["a", "€"]]
      end
    end
  end

  describe "SpreadsheetImportProcessor" do
    let (:search_setup) { instance_double(SearchSetup) }
    let (:imported_file) {
      f = instance_double(ImportedFile)
      allow(f).to receive(:search_setup).and_return search_setup
      allow(f).to receive(:module_type).and_return "Product"
      f
    }
    let (:xl_client) { instance_double(OpenChain::XLClient) }

    subject { FileImportProcessor::SpreadsheetImportProcessor.new imported_file, xl_client }

    describe "get_rows" do
      it "iterates over and yields all rows from xl_client" do
        rows = []
        expect(imported_file).to receive(:starting_row).and_return 2
        expect(xl_client).to receive(:all_row_values).with(starting_row_number: 1).and_yield(["A"]).and_yield(["B"])


        subject.get_rows do |row|
          rows << row
        end

        expect(rows).to eq [["A"], ["B"]]
      end
    end

    it "skips blank lines" do
      rows = []
      expect(imported_file).to receive(:starting_row).and_return 2
      expect(xl_client).to receive(:all_row_values).with(starting_row_number: 1).and_yield(["A"]).and_yield([]).and_yield(["", ""]).and_yield(["B"])


      subject.get_rows do |row|
        rows << row
      end

      expect(rows).to eq [["A"], ["B"]]
    end

    it "throws stop_polling after processing a single row on preview runs" do
      rows = []

      expect(imported_file).to receive(:starting_row).and_return 2
      # Include a blank line so that we ensure we're skipping blank lines in the preview
      expect(xl_client).to receive(:all_row_values).with(starting_row_number: 1, chunk_size: 1).and_yield([]).and_yield(["A"]).and_yield(["B"])

      catch (:stop_polling) do
        subject.get_rows(preview: true) do |row|
          rows << row
        end
        fail("Should have thrown stop_polling.")
      end

      expect(rows).to eq [["A"]]
    end
  end


end
