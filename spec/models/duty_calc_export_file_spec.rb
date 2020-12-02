describe DutyCalcExportFile do
  describe "get_headers" do
    it "gets empty array for standard format" do
      headers = described_class.get_headers :standard
      expect(headers.length).to eq 0
    end

    it "gets empty array for legacy format" do
      headers = described_class.get_headers :legacy
      expect(headers.length).to eq 0
    end

    it "gets empty array for nil format" do
      headers = described_class.get_headers nil
      expect(headers.length).to eq 0
    end
  end

  describe "file generating tests" do
    before :each do
      @importer = create(:company, :importer=>true)
      2.times {DutyCalcExportFileLine.create!(importer_id:@importer.id, export_date:Date.new(2013, 9, 10))}
      FileUtils::mkdir_p 'spec/support/tmp' # make sure directory is there
      @zip_path = 'spec/support/tmp/dce.zip'
      File.delete(@zip_path) if File.exist?(@zip_path)
      @to_del = [@zip_path]
    end

    after :each do
      @to_del.each {|x| File.unlink(x) if File.exist?(x)}
    end

    describe "generate_for_importer" do
      it "should generate excel zip and attach" do
        allow_any_instance_of(DutyCalcExportFileLine).to receive(:make_line_array).with(duty_calc_format: :legacy).and_return(["a", "b"])
        u = create(:master_user)
        expect {DutyCalcExportFile.generate_for_importer @importer, u}.to change(DutyCalcExportFile, :count).from(0).to(1)
        d = DutyCalcExportFile.first
        expect(d.attachment).not_to be_nil
        u.reload
        expect(u.messages.size).to eq(1)
      end

      it "should generate multiple zips" do
        allow_any_instance_of(DutyCalcExportFileLine).to receive(:make_line_array).with(duty_calc_format: :legacy).and_return(["a", "b"])
        expect {DutyCalcExportFile.generate_for_importer(@importer, nil, nil, nil, 1, 1)}.to change(DutyCalcExportFile, :count).from(0).to(2)
      end
    end

    describe "generate_excel_zip" do
      it "should cap at max files" do
        allow_any_instance_of(DutyCalcExportFileLine).to receive(:make_line_array).with(duty_calc_format: :legacy).and_return(["a", "b"])
        2.times {DutyCalcExportFileLine.create!(importer_id:@importer.id, export_date:Date.new(2013, 9, 10))} # makes 4 total because of before each
        d, f = DutyCalcExportFile.generate_excel_zip @importer, @zip_path, 1, nil, 2
        Zip::File.open(f.path) do |zipfile|
          expect(zipfile.dir.entries("/").size).to eq(2)
        end
        # should have 2 files not included because past the max size
        expect(DutyCalcExportFileLine.where(duty_calc_export_file_id:nil).count).to eq 2
      end

      it "should generate a single zipped excel file" do
        allow_any_instance_of(DutyCalcExportFileLine).to receive(:make_line_array).with(duty_calc_format: :legacy).and_return(["a", "b"])
        d, f = DutyCalcExportFile.generate_excel_zip @importer, @zip_path
        Zip::File.open(f.path) do |zipfile|
          expect(zipfile.dir.entries("/").size).to eq(1)
          z_out = 'spec/support/tmp/x.xls'
          @to_del << z_out
          zipfile.extract(zipfile.dir.entries("/").first, z_out)
          workbook = Spreadsheet.open(z_out)
          sheet = workbook.worksheet(0)
          expect(sheet.name).to eq("SHEET1")
          expect(sheet.row(0)[0]).to eq("a")
          expect(sheet.row(0)[1]).to eq("b")
          expect(sheet.row(1)[0]).to eq("a")
          expect(sheet.row(1)[1]).to eq("b")
        end
      end

      it "should generate multiple when the number of lines is over the max_lines_per_file" do
        allow_any_instance_of(DutyCalcExportFileLine).to receive(:make_line_array).with(duty_calc_format: :legacy).and_return(["a", "b"])
        d, f = DutyCalcExportFile.generate_excel_zip @importer, @zip_path, 1
        Zip::File.open(f.path) do |zipfile|
          expect(zipfile.dir.entries("/")).to eq(["File 1.xls", "File 2.xls"])
        end
      end
    end

    describe "generate_csv" do
      it "should output csv for all lines" do
        allow_any_instance_of(DutyCalcExportFileLine).to receive(:make_line_array).with(duty_calc_format: :legacy).and_return(["a", "b"])
        d, t = DutyCalcExportFile.generate_csv @importer
        expect(d.duty_calc_export_file_lines.size).to eq(2)
        expect(d.importer).to eq(@importer)
        expect(CSV.read(t.path).size).to eq(2)
      end

      it "should not output csv for different importer" do
        allow_any_instance_of(DutyCalcExportFileLine).to receive(:make_line_array).with(duty_calc_format: :legacy).and_return(["a", "b"])
        other_company = create(:company, :importer=>true)
        DutyCalcExportFileLine.create!(:importer_id=>other_company.id)
        d, t = DutyCalcExportFile.generate_csv @importer
        expect(d.duty_calc_export_file_lines.size).to eq(2)
        expect(CSV.read(t.path).size).to eq(2)
      end

      it "should restrict by extra where clause" do
        allow_any_instance_of(DutyCalcExportFileLine).to receive(:make_line_array).with(duty_calc_format: :legacy).and_return(["a", "b"])
        w = "duty_calc_export_file_lines.export_date between '2013-01-01' AND '2013-01-05'"
        l = DutyCalcExportFileLine.create!(importer_id:@importer.id, export_date:Date.new(2013, 1, 2))
        d, t = DutyCalcExportFile.generate_csv @importer, Tempfile.new(['dcef', '.csv']), w
        expect(d.duty_calc_export_file_lines.to_a).to eq([l])
        expect(CSV.read(t.path).size).to eq(1)
      end
    end
  end
end
