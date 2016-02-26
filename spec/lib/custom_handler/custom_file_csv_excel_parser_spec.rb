require 'spec_helper'

describe OpenChain::CustomHandler::CustomFileCsvExcelParser do
  subject { Class.new { include OpenChain::CustomHandler::CustomFileCsvExcelParser }.new }
    
  describe "foreach" do
    let (:file_reader) { double("file_reader") }
    let (:custom_file) { double("custom_file") }

    before :each do 
      subject.should_receive(:file_reader).with(custom_file).and_return file_reader
    end
    
    it "processes lines from custom file and returns rows" do
      file_reader.should_receive(:foreach).and_yield(["a", "b", "c"]).and_yield([1, 2, 3])
      rows = subject.foreach(custom_file)
      expect(rows).to eq([["a", "b", "c"], [1, 2, 3]])
    end

    it "processes lines from custom file and yields them" do
      file_reader.should_receive(:foreach).and_yield(["a", "b", "c"]).and_yield([1, 2, 3])
      rows = []
      subject.foreach(custom_file) {|row| rows << row}
      expect(rows).to eq([["a", "b", "c"], [1, 2, 3]])
    end

    it "skips first row if skip_headers is utilized" do
      file_reader.should_receive(:foreach).and_yield(["a", "b", "c"]).and_yield([1, 2, 3])
      rows = subject.foreach(custom_file, skip_headers: true)
      expect(rows).to eq([[1, 2, 3]])
    end

    it "skips blank lines if skip_blank_lines is utilized" do
      file_reader.should_receive(:foreach).and_yield(["    ", "", "    "]).and_yield([nil, nil, nil])
      expect(subject.foreach(custom_file, skip_blank_lines: true)).to be_blank
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

  describe "file_reader" do
    let(:alt_subject) do
      Class.new do 
        include OpenChain::CustomHandler::CustomFileCsvExcelParser 

        def csv_reader_options 
          {test: "csv"}
        end

        def excel_reader_options
          {test: "xls"}
        end
      end.new
    end
    let (:custom_file) { double("custom_file") }

    it "returns CSVReader for csv files" do
      custom_file.stub(:path).and_return "FILE.CSV"
      reader = subject.file_reader custom_file
      expect(reader).to be_a(OpenChain::CustomHandler::CustomFileCsvExcelParser::CsvReader)
      expect(reader.reader_options).to be_blank
    end

    it "returns CSVReader for txt files" do
      custom_file.stub(:path).and_return "FILE.txt"
      expect(subject.file_reader custom_file).to be_a(OpenChain::CustomHandler::CustomFileCsvExcelParser::CsvReader)
    end

    it "returns ExcelReader for xls files" do
      custom_file.stub(:path).and_return "FILE.xls"
      reader = subject.file_reader custom_file
      expect(reader).to be_a(OpenChain::CustomHandler::CustomFileCsvExcelParser::ExcelReader)
      expect(reader.reader_options).to be_blank
    end

    it "returns ExcelReader for xlsx files" do
      custom_file.stub(:path).and_return "FILE.xlsx"
      expect(subject.file_reader custom_file).to be_a(OpenChain::CustomHandler::CustomFileCsvExcelParser::ExcelReader)
    end

    it "sends csv options if implemented" do
      custom_file.stub(:path).and_return "FILE.csv"
      reader = alt_subject.file_reader custom_file
      expect(reader.reader_options).to eq({'test'=> "csv"})
    end

    it "sends xls options if implemented" do
      custom_file.stub(:path).and_return "FILE.xls"
      reader = alt_subject.file_reader custom_file
      expect(reader.reader_options).to eq({'test'=> "xls"})
    end
  end

  describe OpenChain::CustomHandler::CustomFileCsvExcelParser::CsvReader do
    let(:test_file) do
      t = Tempfile.new(["test", ".csv"])
      t << "1,2,3\nA,B,C"
      t.flush
      t.rewind

      t
    end

    let (:custom_file) do
      cf = double("custom_file")
      cf.stub(:bucket).and_return "bucket"
      cf.stub(:path).and_return "path"
      cf
    end

    after :each do
      test_file.close! if test_file && !test_file.closed?
    end

    describe "foreach" do
      it "downloads and reads a file, yielding each row" do
        OpenChain::S3.should_receive(:download_to_tempfile).with("bucket", "path").and_yield test_file

        r = OpenChain::CustomHandler::CustomFileCsvExcelParser::CsvReader.new custom_file, {}
        rows = []
        r.foreach {|row| rows << row} 

        expect(rows).to eq [["1", "2", "3"], ["A", "B", "C"]]
      end

      it "utilizes reader options" do
        OpenChain::S3.should_receive(:download_to_tempfile).with("bucket", "path").and_yield test_file

        r = OpenChain::CustomHandler::CustomFileCsvExcelParser::CsvReader.new custom_file, {headers: true, return_headers: false}
        rows = []
        # when you turn on return_headers, csv yields CSVRow objects...so call fields on them.  This is how
        # we know the options "took"
        r.foreach {|row| rows << row.fields} 

        expect(rows).to eq [["A", "B", "C"]]
      end
    end
  end

  describe OpenChain::CustomHandler::CustomFileCsvExcelParser::ExcelReader do
    let (:custom_file) do
      cf = double("custom_file")
      cf.stub(:bucket).and_return "bucket"
      cf.stub(:path).and_return "path"
      cf
    end

    let (:xl_client) { double("OpenChain::XLClient") }

    describe "foreach" do
      it "yields all row values from a sheet" do
        r = OpenChain::CustomHandler::CustomFileCsvExcelParser::ExcelReader.new(custom_file, {})
        r.should_receive(:xl_client).with("path", {bucket: "bucket"}).and_return xl_client
        xl_client.should_receive(:all_row_values).with(0).and_yield([1,2]).and_yield([3,4])

        rows = []
        r.foreach {|row| rows << row}

        expect(rows).to eq [[1,2], [3,4]]
      end

      it "utilizes reader options" do
        r = OpenChain::CustomHandler::CustomFileCsvExcelParser::ExcelReader.new(custom_file, {sheet_number: 1, bucket: "different_bucket", opt: "opt"})
        r.should_receive(:xl_client).with("path", {bucket: "different_bucket", opt: "opt"}).and_return xl_client
        xl_client.should_receive(:all_row_values).with(1).and_yield([1,2]).and_yield([3,4])

        rows = []
        r.foreach {|row| rows << row}

        expect(rows).to eq [[1,2], [3,4]]
      end
    end
  end
end