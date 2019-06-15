describe OpenChain::CustomHandler::CsvExcelParser do
  
  class FakeCsvExcelParser
    include OpenChain::CustomHandler::CsvExcelParser

    def file_reader file
      raise "Should be mocked."
    end
  end

  subject { FakeCsvExcelParser.new }

  describe "foreach" do
    let (:file_reader) { double("file_reader") }
    let (:file) { double("file") }

    before :each do 
      expect(subject).to receive(:file_reader).with(file).and_return file_reader
    end
    
    it "processes lines from custom file and returns rows" do
      expect(file_reader).to receive(:foreach).and_yield(["a", "b", "c"]).and_yield([1, 2, 3])
      rows = subject.foreach(file)
      expect(rows).to eq([["a", "b", "c"], [1, 2, 3]])
    end

    it "processes lines from custom file and yields them" do
      expect(file_reader).to receive(:foreach).and_yield(["a", "b", "c"]).and_yield([1, 2, 3])
      rows = []
      subject.foreach(file) {|row| rows << row}
      expect(rows).to eq([["a", "b", "c"], [1, 2, 3]])
    end

    it "skips first row if skip_headers is utilized" do
      expect(file_reader).to receive(:foreach).and_yield(["a", "b", "c"]).and_yield([1, 2, 3])
      rows = subject.foreach(file, skip_headers: true)
      expect(rows).to eq([[1, 2, 3]])
    end

    it "skips blank lines if skip_blank_lines is utilized" do
      expect(file_reader).to receive(:foreach).and_yield(["    ", "", "    "]).and_yield([nil, nil, nil])
      expect(subject.foreach(file, skip_blank_lines: true)).to be_blank
    end

    it "receives yielded values" do
      expect(file_reader).to receive(:foreach).and_yield(["a", "b", "c"]).and_yield([1, 2, 3])
      rows = []
      subject.foreach(file) do |row|
        rows << row
      end
      expect(rows).to eq([["a", "b", "c"], [1, 2, 3]])
    end

    it "receives yielded values and row_number" do
      expect(file_reader).to receive(:foreach).and_yield(["a", "b", "c"]).and_yield([1, 2, 3])
      rows = []
      row_numbers = []
      subject.foreach(file) do |row, row_number|
        rows << row
        row_numbers << row_number
      end
      expect(rows).to eq([["a", "b", "c"], [1, 2, 3]])
      expect(row_numbers).to eq [0, 1]
    end
  end

  describe "blank_row?" do
    it "recognizes a blank row" do
      expect(subject.blank_row? [nil, "     ", ""]).to be_truthy
    end

    it "recognizes nil as a blank_row" do
      expect(subject.blank_row? nil).to be_truthy
    end

    it "recognizes non-blank rows" do
      expect(subject.blank_row? [1]).to be_falsey
    end
  end

  describe "date_value" do
    it "returns date from date object" do
      expect(subject.date_value Date.new).to eq Date.new
    end

    it "returns date from DateTime" do
      expect(subject.date_value DateTime.new(2016, 2, 1, 12, 0)).to eq Date.new(2016, 2, 1)
    end

    it "returns date from TimeWithZone" do
      expect(subject.date_value Time.zone.now).to eq Time.zone.now.to_date
    end

    it "returns date from YYYY-mm-dd String" do
      expect(subject.date_value "2016-02-01").to eq Date.new(2016, 2, 1)
    end

    it "returns date from YYYY/mm/dd String" do
      expect(subject.date_value "2016/02/01").to eq Date.new(2016, 2, 1)
    end

    it "returns date from YYYY-m-d String" do
      expect(subject.date_value "2016-2-1").to eq Date.new(2016, 2, 1)
    end

    context "with date validation enabled" do
      before :each do 
        # This logic is only live for non-test envs, to avoid having to update dates in the test files after they get too old
        expect(MasterSetup).to receive(:test_env?).at_least(1).times.and_return false
      end

      context "with really old max age date" do 
        before :each do 
          expect(subject).to receive(:max_valid_date_age_years).at_least(1).times.and_return 100
        end

        it "returns date from mm-dd-yyyy String" do
          expect(subject.date_value "02-01-2016").to eq Date.new(2016, 2, 1)
        end

        it "returns date from mm-dd-yy String" do
          expect(subject.date_value "02-01-16").to eq Date.new(2016, 2, 1)
        end
      end
      
      it "returns nil if date is over max age" do
        expect(subject.date_value (Time.zone.now - 3.years).strftime("%Y-%m-%d")).to eq nil
      end
    end
  end

  describe "text_value" do
    it "strips .0 from values if they're numeric" do
      expect(subject.text_value 1.0).to eq "1"
    end

    it "does not strip meaningful decimal values" do
      expect(subject.text_value BigDecimal("1.0100")).to eq "1.01"
    end

    it "does not strip data from string numeric values" do
      expect(subject.text_value "1.0100").to eq "1.0100"
    end

    it 'does nothing to values that are not numbers' do
      expect(subject.text_value "ABC").to eq "ABC"
    end

    it "strips whitespace by default" do
      expect(subject.text_value " ABC ").to eq "ABC"
    end

    it "does not strip whitespace if instructed" do
      expect(subject.text_value " ABC ", strip_whitespace: false).to eq " ABC "
    end
  end

  describe "decimal_value" do
    it "parses decimal values from strings (removing any trailing / leading whitespace)" do
      expect(subject.decimal_value("   1.2   ")).to eq BigDecimal("1.2")
    end

    it "rounds values if specified" do
      expect(subject.decimal_value("1.25", decimal_places: 1)).to eq BigDecimal("1.3")
    end
  end

  describe "boolean_value" do
    it "parses boolean values from strings (removing any trailing / leading whitespace" do
      expect(subject.boolean_value(" TRUE ")).to eq true
      expect(subject.boolean_value("y")).to eq true
      expect(subject.boolean_value("yes")).to eq true
      expect(subject.boolean_value("1")).to eq true
      
      expect(subject.boolean_value("false")).to eq false
      expect(subject.boolean_value("n")).to eq false
      expect(subject.boolean_value("no")).to eq false
      expect(subject.boolean_value("0")).to eq false
    end
  end

  describe OpenChain::CustomHandler::CsvExcelParser::LocalCsvReader do
    let(:test_file) do
      t = Tempfile.new(["test", ".csv"])
      t << "1,2,3\nA,B,C"
      t.flush
      t.rewind

      t
    end

    after :each do
      test_file.close! if test_file && !test_file.closed?
    end

    describe "foreach" do
      it "reads a file object and parses it" do
        r = OpenChain::CustomHandler::CsvExcelParser::LocalCsvReader.new test_file, {}
        rows = []
        r.foreach {|row| rows << row} 

        expect(rows).to eq [["1", "2", "3"], ["A", "B", "C"]]
      end

      it "utilizes reader options" do
        r = OpenChain::CustomHandler::CsvExcelParser::LocalCsvReader.new test_file, {headers: true, return_headers: false}
        rows = []
        # when you turn on headers, csv yields CSVRow objects...so call fields on them.  This is how
        # we know the options "took"
        r.foreach {|row| rows << row.fields} 

        expect(rows).to eq [["A", "B", "C"]]
      end

      it "parses csv from string directly" do
        r = OpenChain::CustomHandler::CsvExcelParser::LocalCsvReader.new StringIO.new("1,2,3\nA,B,C"), {}
        rows = []
        r.foreach {|row| rows << row} 

        expect(rows).to eq [["1", "2", "3"], ["A", "B", "C"]]
      end

      it "interprets string arg as the path to file" do
        r = OpenChain::CustomHandler::CsvExcelParser::LocalCsvReader.new test_file.path, {}
        rows = []
        r.foreach {|row| rows << row} 

        expect(rows).to eq [["1", "2", "3"], ["A", "B", "C"]]
      end
    end
  end

  describe OpenChain::CustomHandler::CsvExcelParser::LocalExcelReader do
    let (:test_file) do
      wb, sheet = XlsMaker.create_workbook_and_sheet "Sheet1", ["Header1", "Header2"]
      XlsMaker.add_body_row sheet, 1, ["A", "B"]
      sheet2 = XlsMaker.create_sheet wb, "Sheet2", ["Header3", "Header4"]
      XlsMaker.add_body_row sheet2, 1, ["C", "D"]
      tf = Tempfile.new ["test", ".xls"]
      wb.write tf
      tf.flush
      tf.rewind
      tf
    end

    after :each do
      test_file.close! if test_file && !test_file.closed?
    end

    describe "foreach" do
      it "yields all row values from a sheet" do
        r = OpenChain::CustomHandler::CsvExcelParser::LocalExcelReader.new(test_file, {})
        rows = []
        r.foreach {|row| rows << row} 

        expect(rows).to eq [["Header1", "Header2"], ["A", "B"]]
      end

      it "opens to the sheet specified" do
        r = OpenChain::CustomHandler::CsvExcelParser::LocalExcelReader.new(test_file, sheet_number: 1)
        rows = []
        r.foreach {|row| rows << row} 

        expect(rows).to eq [["Header3", "Header4"], ["C", "D"]]
      end
    end
  end
end
