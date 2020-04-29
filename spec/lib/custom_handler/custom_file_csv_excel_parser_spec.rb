describe OpenChain::CustomHandler::CustomFileCsvExcelParser do
  subject { Class.new { include OpenChain::CustomHandler::CustomFileCsvExcelParser }.new }

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
      allow(custom_file).to receive(:path).and_return "FILE.CSV"
      reader = subject.file_reader custom_file
      expect(reader).to be_a(OpenChain::CustomHandler::CustomFileCsvExcelParser::CustomFileCsvReader)
      expect(reader.reader_options).to be_blank
    end

    it "returns CSVReader for txt files" do
      allow(custom_file).to receive(:path).and_return "FILE.txt"
      expect(subject.file_reader custom_file).to be_a(OpenChain::CustomHandler::CustomFileCsvExcelParser::CustomFileCsvReader)
    end

    it "returns ExcelReader for xls files" do
      allow(custom_file).to receive(:path).and_return "FILE.xls"
      reader = subject.file_reader custom_file
      expect(reader).to be_a(OpenChain::CustomHandler::CustomFileCsvExcelParser::CustomFileExcelReader)
      expect(reader.reader_options).to be_blank
    end

    it "returns ExcelReader for xlsx files" do
      allow(custom_file).to receive(:path).and_return "FILE.xlsx"
      expect(subject.file_reader custom_file).to be_a(OpenChain::CustomHandler::CustomFileCsvExcelParser::CustomFileExcelReader)
    end

    it "sends csv options if implemented" do
      allow(custom_file).to receive(:path).and_return "FILE.csv"
      reader = alt_subject.file_reader custom_file
      expect(reader.reader_options).to eq({'test'=> "csv"})
    end

    it "sends xls options if implemented" do
      allow(custom_file).to receive(:path).and_return "FILE.xls"
      reader = alt_subject.file_reader custom_file
      expect(reader.reader_options).to eq({'test'=> "xls"})
    end

    it "raises a NoFileReaderError if a reader doesn't exist for the given file type" do
      allow(custom_file).to receive(:path).and_return "FILE.pdf"
      expect { subject.file_reader custom_file }.to raise_error OpenChain::CustomHandler::CustomFileCsvExcelParser::NoFileReaderError, "No file reader exists for '.pdf' file types."
    end
  end

  describe OpenChain::CustomHandler::CustomFileCsvExcelParser::CustomFileCsvReader do
    let(:test_file) do
      t = Tempfile.new(["test", ".csv"])
      t << "1,2,3\nA,B,C"
      t.flush
      t.rewind

      t
    end

    let (:custom_file) do
      cf = double("custom_file")
      allow(cf).to receive(:bucket).and_return "bucket"
      allow(cf).to receive(:path).and_return "path"
      cf
    end

    after :each do
      test_file.close! if test_file && !test_file.closed?
    end

    describe "foreach" do
      it "downloads and reads a file, yielding each row" do
        expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "path").and_yield test_file

        r = OpenChain::CustomHandler::CustomFileCsvExcelParser::CustomFileCsvReader.new custom_file, {}
        rows = []
        r.foreach {|row| rows << row}

        expect(rows).to eq [["1", "2", "3"], ["A", "B", "C"]]
      end

      it "utilizes reader options" do
        expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "path").and_yield test_file

        r = OpenChain::CustomHandler::CustomFileCsvExcelParser::CustomFileCsvReader.new custom_file, {headers: true, return_headers: false}
        rows = []
        # when you turn on return_headers, csv yields CSVRow objects...so call fields on them.  This is how
        # we know the options "took"
        r.foreach {|row| rows << row.fields}

        expect(rows).to eq [["A", "B", "C"]]
      end
    end
  end

  describe OpenChain::CustomHandler::CustomFileCsvExcelParser::CustomFileExcelReader do
    let (:custom_file) do
      cf = double("custom_file")
      allow(cf).to receive(:bucket).and_return "bucket"
      allow(cf).to receive(:path).and_return "path"
      cf
    end

    let (:xl_client) { double("OpenChain::XLClient") }

    describe "foreach" do
      it "yields all row values from a sheet" do
        r = OpenChain::CustomHandler::CustomFileCsvExcelParser::CustomFileExcelReader.new(custom_file, {})
        expect(r).to receive(:get_xl_client).with("path", {bucket: "bucket"}).and_return xl_client
        expect(xl_client).to receive(:all_row_values).with(sheet_number: 0).and_yield([1, 2]).and_yield([3, 4])

        rows = []
        r.foreach {|row| rows << row}

        expect(rows).to eq [[1, 2], [3, 4]]
      end

      it "utilizes reader options" do
        r = OpenChain::CustomHandler::CustomFileCsvExcelParser::CustomFileExcelReader.new(custom_file, {sheet_number: 1, bucket: "different_bucket", opt: "opt"})
        expect(r).to receive(:get_xl_client).with("path", {bucket: "different_bucket", opt: "opt"}).and_return xl_client
        expect(xl_client).to receive(:all_row_values).with(sheet_number: 1).and_yield([1, 2]).and_yield([3, 4])

        rows = []
        r.foreach {|row| rows << row}

        expect(rows).to eq [[1, 2], [3, 4]]
      end
    end
  end
end