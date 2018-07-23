describe CsvBuilder do

  def raw_csv_data
    io = StringIO.new 
    subject.write io
    io.rewind
    io.read
  end

  describe "create_sheet" do
    it "creates a new sheet without headers" do
      sheet = subject.create_sheet "name"
      expect(sheet.name).to eq "name"
      expect(sheet).to be_a CsvBuilder::CsvSheet
      expect(sheet.raw_sheet).to be_a CSV
    end

    it "creates a new sheet with headers" do
      sheet = subject.create_sheet "name", headers: ["Header"]
      expect(raw_csv_data).to eq "Header\n"
    end
  end

  describe "add_body_row" do
    let (:sheet) { subject.create_sheet "Sheet" }
    
    it "adds a new row" do
      expect(subject.add_body_row sheet, ["Body"]).to be_nil
      expect(raw_csv_data).to eq "Body\n"
    end

    context "with special field handling" do 
      it "formats dates as YYYY-MM-DD" do
        expect(subject.add_body_row sheet, [Date.new(2018, 7, 13)]).to be_nil
        expect(raw_csv_data).to eq "2018-07-13\n"
      end

      it "formates DateTime as YYYY-MM-DD HH:MM" do
        expect(subject.add_body_row sheet, [DateTime.new(2018, 7, 13, 12, 23, 30)]).to be_nil
        expect(raw_csv_data).to eq "2018-07-13 12:23\n"
      end

      it "formats ActivSupport::TimeWithZone as YYYY-MM-DD HH:MM" do
        expect(subject.add_body_row sheet, [Time.zone.parse("2018-07-13 12:23")]).to be_nil
        expect(raw_csv_data).to eq "2018-07-13 12:23\n"
      end

      it "replaces all carriage returns in row data with spaces" do
        expect(subject.add_body_row sheet, ["Body\rText"]).to be_nil
        expect(raw_csv_data).to eq "Body Text\n"
      end

      it "replaces all linefeeds in row data with spaces" do
        expect(subject.add_body_row sheet, ["Body\nText"]).to be_nil
        expect(raw_csv_data).to eq "Body Text\n"
      end
    end
  end

  describe "add_header_row" do
    let (:sheet) { subject.create_sheet "Sheet" }
    
    it "adds a new row" do
      expect(subject.add_header_row sheet, ["Header"]).to be_nil
      expect(raw_csv_data).to eq "Header\n"
    end
  end

  describe "write" do
    let! (:sheet) { 
      # This initializes the csv internals
      subject.create_sheet "Sheet", headers: ["Testing"]
    }

    it "writes data to given IO object" do
      io = StringIO.new
      subject.write io
      io.rewind
      expect(io.read).to eq "Testing\n"
    end

    it "writes data to given file path" do
      Tempfile.open(["test", ".csv"]) do |file|
        subject.write file.path

        expect(file.read).to eq "Testing\n"
      end
    end
  end
end