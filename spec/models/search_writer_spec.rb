describe SearchWriter do

  describe "write_search" do
    let! (:ms) { stub_master_setup }
    let(:user) { Factory(:user) }
    let(:search_setup) { 
      # for the basic search stuff, we're going to use csv since it's easier to read back
      ss = SearchSetup.new module_type: "Product", user: user, name: 'search', download_format: "csv"
      ss.search_columns.build model_field_uid: "prod_uid", rank: 2
      ss.search_columns.build model_field_uid: "prod_name", rank: 1
      ss.search_criterions.build model_field_uid: "prod_uid", operator: "eq", value: "uid"
      ss.search_criterions.build model_field_uid: "prod_name", operator: "eq", value: "name"

      ss.save!
      ss
    }

    let (:search_results_hash) {
      {row_key: 100, result: ["A", 1, Date.new(2018, 7, 16), Time.zone.parse("2018-07-16 12:30")]}
    }

    subject { described_class.new search_setup }

    def standard_run expected_query_opts: {}, max_results: nil, audit: nil, use_tempfile: nil, builder_class: CsvBuilder, builder_sheet_class: CsvBuilder::CsvSheet, skip_builder_expectations: false, original_filename: "Report name.xlsx"
      s = use_tempfile ? Tempfile.new(["file",".xlsx"]) : StringIO.new
      Attachment.add_original_filename_method(s, original_filename)
      opts = {raise_max_results_error: true}.merge expected_query_opts
      expect_any_instance_of(SearchQuery).to receive(:execute).with(opts).and_yield search_results_hash
      if !skip_builder_expectations
        expect_any_instance_of(builder_class).to receive(:freeze_horizontal_rows).with(instance_of(builder_sheet_class), 1)
        expect_any_instance_of(builder_class).to receive(:apply_min_max_width_to_columns).with(instance_of(builder_sheet_class))
      end

      expect(subject.write_search s, max_results: max_results, audit: audit).to eq 1
      s.rewind
      s
    end

    it "executes a search and writes it to a given IO object" do
      output = CSV.parse(standard_run.read)
      expect(output[0]).to eq ["Name", "Unique Identifier"]
      expect(output[1]).to eq ["A", "1", "2018-07-16", "2018-07-16 12:30"]
    end

    it "includes weblinks if instructed to" do
      search_setup.include_links = true
      output = CSV.parse(standard_run.read)
      expect(output[0]).to eq ["Name", "Unique Identifier", "Links"]
      expect(output[1]).to eq ["A", "1", "2018-07-16", "2018-07-16 12:30", "http://localhost:3000/products/100"]
    end

    it "transforms datetimes to dates if instructed" do 
      search_setup.no_time = true
      output = CSV.parse(standard_run.read)

      expect(output[1]).to eq ["A", "1", "2018-07-16", "2018-07-16"]
    end

    it "limits search results if instructed" do
      standard_run(expected_query_opts: {per_page: 1}, max_results: 1)      
    end

    it "hides model field labels users can't see" do
      expect(ModelField.find_by_uid(:prod_uid)).to receive(:can_view?).with(user).at_least(1).times.and_return false
      output = CSV.parse(standard_run.read)
      expect(output[0]).to eq ["Name", "[Disabled]"]
    end

    it "substitutes audit for search results" do
      # feature doesn't really work without multiple records, so just check that it ran and produced a header row
      expect(OpenChain::RandomAuditGenerator).to receive(:run).with([search_results_hash], 0, "header").and_call_original
      file = standard_run(use_tempfile: true, audit:{"record_type" => "header", "percent" => 0})
      output = CSV.parse(file.read)
      expect(output[0]).to eq ["Name", "Unique Identifier"]
      file.close
    end

    context "with xls output" do
      before :each do 
        search_setup.download_format = "xls"
      end

      it "writes criteria tab" do
        now = Time.zone.now
        s = nil
        Timecop.freeze(now) do 
          s = Spreadsheet.open standard_run(skip_builder_expectations: true)
        end

        sheet = s.worksheet "Search Parameters"
        expect(sheet).not_to be_nil
        expect(sheet.row(0).to_a).to eq ["Parameter Name", "Parameter Value"]
        expect(sheet.row(1).to_a).to eq ["User Name", user.full_name]
        expect(sheet.row(2).to_a[0]).to eq "Report Run Time"
        expect(sheet.row(2).to_a[1].to_i).to eq now.to_datetime.to_i
        expect(sheet.row(3).to_a).to eq ["Customer", user.company.name]

        expect(sheet.row(4).to_a).to eq ["Unique Identifier", "Equals uid"]
        expect(sheet.row(5).to_a).to eq ["Name", "Equals name"]

        expect(s.worksheet "Results").not_to be_nil
      end

      it "splits criteria tab into multiple cells if it has more than 1024 chars" do
        value = ""
        150.times { value << "1234567890\n"}
        sc = search_setup.search_criterions.first
        sc.update_attributes! value: value

        s = Spreadsheet.open standard_run(skip_builder_expectations: true)
        sheet = s.worksheet "Search Parameters"
        expect(sheet).not_to be_nil
        
        # Since the value had too much data, it overflowed to the second cell so the row should
        # have 3 cells
        expect(sheet.row(4).to_a.length).to eq 3
        expect(sheet.row(4).to_a[1]).to eq "Equals #{value.each_line.to_a[0..91].join.chomp}"
        expect(sheet.row(4).to_a[2]).to eq "#{value.each_line.to_a[92..149].join.chomp}"
      end

      it "splits criteria tab into multiple cells if it has more than 152 newlines" do
        value = ""
        170.times { value << "1\n"}
        sc = search_setup.search_criterions.first
        sc.update_attributes! value: value

        s = Spreadsheet.open standard_run(skip_builder_expectations: true)
        sheet = s.worksheet "Search Parameters"
        expect(sheet).not_to be_nil
        
        # Since the value had too much data, it overflowed to the second cell so the row should
        # have 3 cells
        expect(sheet.row(4).to_a.length).to eq 3
        expect(sheet.row(4).to_a[1]).to eq "Equals #{value.each_line.to_a[0..150].join.chomp}"
        expect(sheet.row(4).to_a[2]).to eq "#{value.each_line.to_a[151..169].join.chomp}"
      end

      it "writes audit tab and logs audit", paperclip: true, s3: true do
        now = Time.zone.now
        file = nil; s = nil
        
        RandomAudit.destroy_all
        
        Timecop.freeze(now) do 
          file = standard_run(use_tempfile: true, skip_builder_expectations: true, audit: {"percent" => 0, "record_type" => "header"})
          s = Spreadsheet.open file
        end

        sheet = s.worksheet "Audit"
        expect(sheet).not_to be_nil
        expect(sheet.row(0).to_a).to eq ["Name", "Unique Identifier"]
        
        expect(s.worksheet "Results").not_to be_nil
        
        params_sheet = s.worksheet "Search Parameters"
        expect(params_sheet.row(6).to_a).to eq ["Audit Percentage", 0]
        expect(params_sheet.row(7).to_a).to eq ["Dataset to Audit", "header"]

        expect(RandomAudit.count).to eq 1
        ra = RandomAudit.first
        expect(ra.search_setup).to eq search_setup
        expect(ra.module_type).to eq "Product"
        expect(ra.attached_file_name).to eq "Report name.xlsx"
        expect(ra.report_date).to be_within(1).of now
        expect(ra.user).to eq user
        
        #test copy
        audit_log = StringIO.new OpenChain::S3.get_data('chain-io', ra.attached.path)
        sheet = Spreadsheet.open(audit_log).worksheet "Audit"
        expect(sheet).not_to be_nil
        expect(sheet.row(0).to_a).to eq ["Name", "Unique Identifier"]

        file.close
      end
    end

    context "with xlsx output" do
      before :each do 
        search_setup.download_format = "xlsx"
      end

      it "writes criteria tab" do
        now = Time.zone.now
        xlsx = nil
        Timecop.freeze(now) do 
          xlsx = XlsxTestReader.new standard_run(skip_builder_expectations: true)
        end

        sheet = xlsx.sheet "Search Parameters"
        expect(sheet).not_to be_nil
        rows = xlsx.raw_data sheet

        expect(rows[0]).to eq ["Parameter Name", "Parameter Value"]
        expect(rows[1]).to eq ["User Name", user.full_name]
        expect(rows[2][0]).to eq "Report Run Time"
        expect(rows[2][1].to_i).to eq now.to_i
        expect(rows[3]).to eq ["Customer", user.company.name]

        expect(rows[4]).to eq ["Unique Identifier", "Equals uid"]
        expect(rows[5]).to eq ["Name", "Equals name"]

        expect(xlsx.sheet "Results").not_to be_nil
      end

      it "splits criteria tab into multiple cells if it has more than 1024 chars" do
        value = ""
        150.times { value << "1234567890\n"}
        sc = search_setup.search_criterions.first
        sc.update_attributes! value: value

        xlsx = XlsxTestReader.new standard_run(skip_builder_expectations: true)
        sheet = xlsx.sheet "Search Parameters"
        expect(sheet).not_to be_nil

        rows = xlsx.raw_data sheet
        
        # Since the value had too much data, it overflowed to the second cell so the row should
        # have 3 cells
        expect(rows[4].length).to eq 3
        expect(rows[4][1]).to eq "Equals #{value.each_line.to_a[0..91].join.chomp}"
        expect(rows[4][2]).to eq "#{value.each_line.to_a[92..149].join.chomp}"
      end

      it "splits criteria tab into multiple cells if it has more than 152 newlines" do
        value = ""
        170.times { value << "1\n"}
        sc = search_setup.search_criterions.first
        sc.update_attributes! value: value

        # Since the value had too much data, it overflowed to the second cell so the row should
        # have 3 cells

        xlsx = XlsxTestReader.new standard_run(skip_builder_expectations: true)
        sheet = xlsx.sheet "Search Parameters"
        expect(sheet).not_to be_nil

        rows = xlsx.raw_data sheet
        
        # Since the value had too much data, it overflowed to the second cell so the row should
        # have 3 cells
        expect(rows[4].length).to eq 3
        expect(rows[4][1]).to eq "Equals #{value.each_line.to_a[0..150].join.chomp}"
        expect(rows[4][2]).to eq "#{value.each_line.to_a[151..169].join.chomp}"
      end

      it "writes audit tab (if specified)" do
        now = Time.zone.now
        xlsx = nil; file = nil
        Timecop.freeze(now) do 
          file = standard_run(use_tempfile: true, skip_builder_expectations: true, audit: {"percent" => 0, "record_type" => "header"})
          xlsx = XlsxTestReader.new file
        end

        sheet = xlsx.sheet "Audit"
        expect(sheet).not_to be_nil
        rows = xlsx.raw_data sheet

        expect(rows[0]).to eq ["Name", "Unique Identifier"]
        
        expect(xlsx.sheet "Results").not_to be_nil
        
        params_sheet = xlsx.sheet "Search Parameters"
        params_rows = xlsx.raw_data params_sheet
        expect(params_rows[6]).to eq ["Audit Percentage", 0]
        expect(params_rows[7]).to eq ["Dataset to Audit", "header"]
        file.close
      end
    end

  end

end
