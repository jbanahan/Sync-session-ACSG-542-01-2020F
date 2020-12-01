describe DutyCalcImportFile do
  before :each do
    @importer = FactoryBot(:company, :importer=>true)
    @product = FactoryBot(:product)
    2.times {DrawbackImportLine.create!(importer_id:@importer.id,
      product:@product, quantity:10
    )}
    @zip_path = 'spec/support/tmp/dci.zip'
    File.delete(@zip_path) if File.exist?(@zip_path)
    @to_del = [@zip_path]
    @user = FactoryBot(:user)
  end

  after :each do
    @to_del.each {|x| File.unlink(x) if File.exist?(x)}
  end

  describe "generate_for_importer" do
    it "should generate excel zip and attach using default legacy duty calc format" do
      zip = double('outputzip')
      expect(zip).to receive(:original_filename=).with('abc.txt')
      dcif = DutyCalcImportFile.create!(importer_id:@importer.id)
      att = double('attachment')
      expect(Attachment).to receive(:add_original_filename_method).with(zip)
      expect(DutyCalcImportFile).to receive(:generate_excel_zip).with(@importer, @user, 'tmp/abc.txt', duty_calc_format: :legacy).and_return([dcif, zip])
      expect(dcif).to receive(:build_attachment).and_return att
      expect(att).to receive(:attached=).with(zip)
      expect(att).to receive(:save!).and_return(true)
      out_obj, out_file = DutyCalcImportFile.generate_for_importer @importer, @user, 'tmp/abc.txt'
      expect(out_obj).to eq(dcif)
      expect(out_file).to eq(zip)
      @user.reload
      expect(@user.messages.size).to eq(1)
    end

    it "should pass through a provided duty calc format" do
      zip = double('outputzip')
      expect(zip).to receive(:original_filename=).with('abc.txt')
      dcif = DutyCalcImportFile.create!(importer_id:@importer.id)
      att = double('attachment')
      expect(Attachment).to receive(:add_original_filename_method).with(zip)
      expect(DutyCalcImportFile).to receive(:generate_excel_zip).with(@importer, nil, 'tmp/abc.txt', duty_calc_format: :standard).and_return([dcif, zip])
      expect(dcif).to receive(:build_attachment).and_return att
      expect(att).to receive(:attached=).with(zip)
      expect(att).to receive(:save!).and_return(true)
      out_obj, out_file = DutyCalcImportFile.generate_for_importer @importer.id, nil, 'tmp/abc.txt', duty_calc_format: :standard
      expect(out_obj).to eq(dcif)
      expect(out_file).to eq(zip)
    end
  end

  describe "generate_excel_zip" do
    it "should generate a single zipped excel file using default legacy duty calc format" do
      expect(DutyCalcImportFile).to receive(:get_line_array).with(instance_of(DrawbackImportLine), :legacy).and_return(["a", "b"]).twice

      d, f = DutyCalcImportFile.generate_excel_zip @importer, @user, @zip_path
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
      expect(d.duty_calc_import_file_lines.pluck(:drawback_import_line_id).sort).to eq(DrawbackImportLine.all.pluck(:id).sort)
    end

    it "should generate a single zipped excel file using provided duty calc format" do
      expect(DutyCalcImportFile).to receive(:get_line_array).with(instance_of(DrawbackImportLine), :standard).and_return(["a", "b"]).twice

      d, f = DutyCalcImportFile.generate_excel_zip @importer, @user, @zip_path, duty_calc_format: :standard
    end

    it "should generate multiple when the number of lines is over the max_lines_per_file" do
      d, f = DutyCalcImportFile.generate_excel_zip @importer, @user, @zip_path, 1
      Zip::File.open(f.path) do |zipfile|
        expect(zipfile.dir.entries("/")).to eq(["File 1.xls", "File 2.xls"])
      end
    end
  end

  describe "get_headers" do
    it "gets empty array for standard format" do
      headers = DutyCalcImportFile.get_headers :standard
      expect(headers.length).to eq 0
    end

    it "gets empty array for legacy format" do
      headers = DutyCalcImportFile.get_headers :legacy
      expect(headers.length).to eq 0
    end

    it "gets empty array for nil format" do
      headers = DutyCalcImportFile.get_headers nil
      expect(headers.length).to eq 0
    end
  end

  describe "get_line_array" do
    it "gets standard array for standard format" do
      line = DrawbackImportLine.first
      expect(line).to receive(:duty_calc_line_array_standard).and_return(["a", "b"])
      DutyCalcImportFile.get_line_array line, :standard
    end

    it "gets legacy array for legacy format" do
      line = DrawbackImportLine.first
      expect(line).to receive(:duty_calc_line_array_legacy).and_return(["a", "b"])
      DutyCalcImportFile.get_line_array line, :legacy
    end

    it "gets legacy array for nil format" do
      line = DrawbackImportLine.first
      expect(line).to receive(:duty_calc_line_array_legacy).and_return(["a", "b"])
      DutyCalcImportFile.get_line_array line, nil
    end
  end
end