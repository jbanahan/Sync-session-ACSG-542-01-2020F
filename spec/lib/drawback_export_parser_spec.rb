require 'spec_helper'

describe OpenChain::DrawbackExportParser do

  describe "parse_zip_file" do
    
    it "should extract files from zip" do
      file_names = []
      allow(described_class).to receive(:parse_file) do |f, importer|
        expect(f).to be_a Tempfile
        file_names << File.basename(f)
      end

      File.open("spec/fixtures/files/test_sheets.zip", "r") do |zip_file|
        described_class.parse_zip_file(zip_file, "importer")
      end

      file_names.uniq!
      expect(file_names.size).to eq 3
      file_names.each do |fn|
        if !fn.match(/test_sheet_1.+xls/) && !fn.match(/test_sheet_2.+xlsx/) && !fn.match(/test_sheet_3.+csv/)
          fail(fn)
        end
      end
    end
  end

  describe "parse_file" do

    it "should delegate to parse_local_xls for an xls or xlsx" do
      
      File.open("spec/fixtures/files/test_sheet_1.xls", "r") do |xls_file|
        expect(described_class).to receive(:parse_local_xls).with(xls_file, "importer")
        described_class.parse_file(xls_file, "importer")
      end

      File.open("spec/fixtures/files/test_sheet_2.xlsx", "r") do |xlsx_file|
        expect(described_class).to receive(:parse_local_xls).with(xlsx_file, "importer")
        described_class.parse_file(xlsx_file, "importer")
      end
    end
    
    it "should delegate to parse_zip_file for a zip" do
      File.open("spec/fixtures/files/test_sheets.zip", "r") do |zip_file|
        expect(described_class).to receive(:parse_zip_file).with(zip_file, "importer")
        described_class.parse_file(zip_file, "importer")
      end
    end

    it "should delegate to parse_csv_file for a csv or txt" do
            
      File.open("spec/fixtures/files/test_sheet_3.csv", "r") do |csv_file|
        expect(described_class).to receive(:parse_csv_file).with(csv_file.path, "importer")
        described_class.parse_file(csv_file, "importer")
      end

      File.open("spec/fixtures/files/test_sheet_4.txt", "r") do |txt_file|
        expect(described_class).to receive(:parse_csv_file).with(txt_file.path, "importer")
        described_class.parse_file(txt_file, "importer")
      end

    end

    it "should raise exception for an unrecognized file type" do
      File.open("spec/fixtures/files/test_sheet_5.foo", "r") do |foo_file|
        expect{ described_class.parse_file(foo_file, "importer") }.to raise_error(ArgumentError, "File extension not recognized")
      end
    end
  end

  describe "parse_local_xls" do
    it "should delegate to S3.with_s3_temp_file and parse_xlsx_file" do
      
      mock_s3_obj = double('s3_obj')
      mock_bucket = double("bucket")
      allow(mock_bucket).to receive(:name).and_return "temp-bucket"
      allow(mock_s3_obj).to receive(:key).and_return("abcdefg/temp/test_sheet_1.xls")
      allow(mock_s3_obj).to receive(:bucket).and_return mock_bucket

      expect(described_class).to receive(:parse_xlsx_file).with("temp-bucket", "abcdefg/temp/test_sheet_1.xls", "importer")
      File.open("spec/fixtures/files/test_sheet_1.xls", "r") do |xls_file|
        expect(OpenChain::S3).to receive(:with_s3_tempfile).with(xls_file).and_yield(mock_s3_obj)
        described_class.parse_local_xls(xls_file, "importer")
      end
    end
  end


  describe "parse_xlsx_file" do
    it "uses xlclient to retrieve xl data and passes data to csv lines" do
      data = [["header"], ["row"]]
      xl_client = double("OpenChain::XLClient")
      expect(xl_client).to receive(:all_row_values).with(0).and_yield(data[0]).and_yield(data[1])
      expect(described_class).to receive(:xl_client).with("bucket", "path").and_return xl_client
      line = DutyCalcExportFileLine.new
      expect(described_class).to receive(:parse_csv_line).with(data[1], 1, "importer").and_return line

      described_class.parse_xlsx_file "bucket", "path", "importer"
      expect(line).to be_persisted
    end
  end

end