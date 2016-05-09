require 'spec_helper'

describe OpenChain::CustomHandler::CsvExcelParser do
  subject { Class.new { include OpenChain::CustomHandler::CsvExcelParser }.new }

  describe "foreach" do
    let (:file_reader) { double("file_reader") }
    let (:file) { double("file") }

    before :each do 
      subject.should_receive(:file_reader).with(file).and_return file_reader
    end
    
    it "processes lines from custom file and returns rows" do
      file_reader.should_receive(:foreach).and_yield(["a", "b", "c"]).and_yield([1, 2, 3])
      rows = subject.foreach(file)
      expect(rows).to eq([["a", "b", "c"], [1, 2, 3]])
    end

    it "processes lines from custom file and yields them" do
      file_reader.should_receive(:foreach).and_yield(["a", "b", "c"]).and_yield([1, 2, 3])
      rows = []
      subject.foreach(file) {|row| rows << row}
      expect(rows).to eq([["a", "b", "c"], [1, 2, 3]])
    end

    it "skips first row if skip_headers is utilized" do
      file_reader.should_receive(:foreach).and_yield(["a", "b", "c"]).and_yield([1, 2, 3])
      rows = subject.foreach(file, skip_headers: true)
      expect(rows).to eq([[1, 2, 3]])
    end

    it "skips blank lines if skip_blank_lines is utilized" do
      file_reader.should_receive(:foreach).and_yield(["    ", "", "    "]).and_yield([nil, nil, nil])
      expect(subject.foreach(file, skip_blank_lines: true)).to be_blank
    end

    it "receives yielded values" do
      file_reader.should_receive(:foreach).and_yield(["a", "b", "c"]).and_yield([1, 2, 3])
      rows = []
      subject.foreach(file) do |row|
        rows << row
      end
      expect(rows).to eq([["a", "b", "c"], [1, 2, 3]])
    end

    it "receives yielded values and row_number" do
      file_reader.should_receive(:foreach).and_yield(["a", "b", "c"]).and_yield([1, 2, 3])
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
      expect(subject.blank_row? [nil, "     ", ""]).to be_true
    end

    it "recognizes nil as a blank_row" do
      expect(subject.blank_row? nil).to be_true
    end

    it "recognizes non-blank rows" do
      expect(subject.blank_row? [1]).to be_false
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

    it "returns date from mm-dd-yyyy String" do
      expect(subject.date_value "02-01-2016").to eq Date.new(2016, 2, 1)
    end

    it "returns date from mm-dd-yy String" do
      expect(subject.date_value "02-01-16").to eq Date.new(2016, 2, 1)
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
  end

  describe "decimal_value" do
    it "parses decimal values from strings (removing any trailing / leading whitespace)" do
      expect(subject.decimal_value("   1.2   ")).to eq BigDecimal("1.2")
    end

    it "rounds values if specified" do
      expect(subject.decimal_value("1.25", decimal_places: 1)).to eq BigDecimal("1.3")
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