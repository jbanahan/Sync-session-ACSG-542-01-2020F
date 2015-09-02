require 'spec_helper'

describe OpenChain::DrawbackExportParser do

  describe "parse_zip_file" do
    before(:each) do
      @zip = File.open("spec/fixtures/files/test_sheets.zip", "r")
    end

    it "should extract files from zip" do
      file_names = []
      described_class.stub(:parse_file) do |f, importer|
        expect(f).to be_a Tempfile
        file_names << File.basename(f)
      end

      described_class.parse_zip_file(@zip, "importer")

      file_names.uniq!
      expect(file_names.size).to eq 3
      file_names.each do |fn|
        if !fn.match(/test_sheet_1.xls/) && !fn.match(/test_sheet_2.xlsx/) && !fn.match(/test_sheet_3.csv/)
          fail(fn)
        end
      end
    end
  end

  describe "parse_file" do

    it "should delegate to parse_local_xls for an xls or xlsx" do
      xls_file = File.open("spec/fixtures/files/test_sheet_1.xls", "r")
      xlsx_file = File.open("spec/fixtures/files/test_sheet_2.xlsx", "r")

      described_class.should_receive(:parse_local_xls).with(xls_file, "importer")
      described_class.parse_file(xls_file, "importer")

      described_class.should_receive(:parse_local_xls).with(xlsx_file, "importer")
      described_class.parse_file(xlsx_file, "importer")
    end
    
    it "should delegate to parse_zip_file for a zip" do
      zip_file = File.open("spec/fixtures/files/test_sheets.zip", "r")
      described_class.should_receive(:parse_zip_file).with(zip_file, "importer")
      described_class.parse_file(zip_file, "importer")
    end

    it "should delegate to parse_csv_file for a csv or txt" do
      csv_file = File.open("spec/fixtures/files/test_sheet_3.csv", "r")
      txt_file = File.open("spec/fixtures/files/test_sheet_4.txt", "r")
      
      described_class.should_receive(:parse_csv_file).with(csv_file.path, "importer")
      described_class.parse_file(csv_file, "importer")

      described_class.should_receive(:parse_csv_file).with(txt_file.path, "importer")
      described_class.parse_file(txt_file, "importer")
    end

    it "should raise exception for an unrecognized file type" do
      foo_file = File.open("spec/fixtures/files/test_sheet_5.foo", "r")
      expect{ described_class.parse_file(foo_file, "importer") }.to raise_error(ArgumentError, "File extension not recognized")
    end
  end

  describe "parse_local_xls" do
    it "should delegate to S3.with_s3_temp_file and parse_xlsx_file" do
      xls_file = File.open("spec/fixtures/files/test_sheet_1.xls", "r")
      master_setup = double("master setup")
      master_setup.stub(:uuid).and_return('abcdefg')
      MasterSetup.stub(:get).and_return(master_setup)

      OpenChain::S3.should_receive(:with_s3_tempfile).with(xls_file).and_call_original
      described_class.should_receive(:parse_xlsx_file).with("abcdefg/temp/test_sheet_1.xls", "importer")

      described_class.parse_local_xls(xls_file, "importer")
    end
  end

end