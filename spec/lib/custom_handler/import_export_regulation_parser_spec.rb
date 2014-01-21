require 'spec_helper'

describe OpenChain::CustomHandler::ImportExportRegulationParser do

  before :each do
    @country =  Factory(:country, :iso_code => 'TW')
  end

  context :process_file do
    it "should look up the country and call process" do
      OpenChain::CustomHandler::ImportExportRegulationParser.any_instance.should_receive(:process)
      OpenChain::CustomHandler::ImportExportRegulationParser.process_file nil, @country.iso_code
    end

    it "should raise an error if the country doesn't exist" do
      expect{OpenChain::CustomHandler::ImportExportRegulationParser.process_file nil, 'Blargh!'}.to raise_error "Blargh! is invalid."
    end
  end

  describe "process" do
    it "raises an error for countries that are not configured" do
      country = Factory(:country)
      expect{OpenChain::CustomHandler::ImportExportRegulationParser.new(country).process(StringIO.new, 'file.txt')}.to raise_error "The Import/Export Regulation Parser is not capable of processing .txt files for '#{country.iso_code}'."
    end

    it "raises an error for country formats that are not configured" do
      expect{OpenChain::CustomHandler::ImportExportRegulationParser.new(@country).process(StringIO.new, 'file.blah')}.to raise_error "The Import/Export Regulation Parser is not capable of processing .blah files for '#{@country.iso_code}'."
    end
  end

  context "process TW data" do 
    before :each do
      @tariff1 = Factory(:official_tariff, :country_id => @country.id, :hts_code => '01011000104', :import_regulations=> 'blah', :export_regulations => 'yada')
      @tariff2 = Factory(:official_tariff, :country_id => @country.id, :hts_code => '01011000202', :import_regulations=> 'blah', :export_regulations => 'yada')
      @tariff3 = Factory(:official_tariff, :country_id => @country.id, :hts_code => '01019000107', :import_regulations=> 'blah', :export_regulations => 'yada')

      @data = "Tariff No.    date    date   specific  ad valoren    specific  ad valoren    Unit      Quantity     Mark          Import  Regulations                      Export  Regulations\n" + \
              "=========== ======= =======  ========  ==========    ========  ==========  ========  ============  ============  =======================================  =======================================\r\n" + \
              "01011000104 1020101 9999999               2.50%                    2.50%              HED    KGM                  401 B01                                  441                                   \r\n" + \
              "01011000202 1020101 9999999               2.50%                    2.50%              HED    KGM                  B01\n" + \
              "01019000107 1020101 9999999               2.50%                    2.50%              HED    KGM\n" + \
              "01019000111 1020101 9999999               2.50%                    2.50%              HED    KGM\n"
      @parser = OpenChain::CustomHandler::ImportExportRegulationParser.new @country
    end

    context "fixed_width" do

      it "should process a fixed-width TW import file" do
        io = StringIO.new @data
        @parser.process io, 'file.txt'

        @tariff1.reload
        @tariff1.import_regulations.should == "401 B01"
        @tariff1.export_regulations.should == "441"

        @tariff2.reload
        @tariff2.import_regulations.should == "B01"
        @tariff2.export_regulations.should == ""

        @tariff3.reload
        @tariff3.import_regulations.should == ""
        @tariff3.export_regulations.should == ""
      end
    end

    context "xls" do
      before :each do
        wb = Spreadsheet::Workbook.new
        sheet = wb.create_worksheet :name=>"TW"
        sheet.row(0).push(@tariff1.hts_code, nil, nil, nil, nil, nil, nil, nil, nil, "401 B01", "441")
        sheet.row(1).push(@tariff2.hts_code, nil, nil, nil, nil, nil, nil, nil, nil, "B01")
        sheet.row(2).push(@tariff3.hts_code)

        @xls = Tempfile.open(["ImpExpTest", ".xls"])
        @xls.binmode
        wb.write(@xls)
        @xls.flush
        @xls.rewind
      end

      after :each do 
        @xls.close!
      end

      it "should process an xls TW import file" do
        @parser.process @xls

        @tariff1.reload
        @tariff1.import_regulations.should == "401 B01"
        @tariff1.export_regulations.should == "441"

        @tariff2.reload
        @tariff2.import_regulations.should == "B01"
        @tariff2.export_regulations.should == ""

        @tariff3.reload
        @tariff3.import_regulations.should == ""
        @tariff3.export_regulations.should == ""
      end
    end

    describe "process_s3" do
      before :each do
        #Upload the data contents to S3
        @original_tempfile = Tempfile.new('abc')
        @key = "s3_io_#{Time.now.to_f}.txt"
        @original_tempfile.write @data
        @original_tempfile.flush
        @original_tempfile.rewind
      end

      after :each do
        @original_tempfile.close!
      end
      
      it "should download a file from S3 and process it" do
        OpenChain::S3.should_receive(:download_to_tempfile).with(OpenChain::S3.bucket_name, @key).and_yield @original_tempfile

        # We're using the S3 path as the full integration test because it hits every portion
        # of the regulation parser code.
        OpenChain::CustomHandler::ImportExportRegulationParser.process_s3 @key, 'TW'

        @tariff1.reload
        @tariff1.import_regulations.should == "401 B01"
        @tariff1.export_regulations.should == "441"

        @tariff2.reload
        @tariff2.import_regulations.should == "B01"
        @tariff2.export_regulations.should == ""

        @tariff3.reload
        @tariff3.import_regulations.should == ""
        @tariff3.export_regulations.should == ""
      end
    end
  end
end