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

  context :process_s3 do
    it "should use S3 helper to process a file from S3" do
      # We'll do a full integration test below
      t = double('tempfile')
      OpenChain::S3.should_receive(:bucket_name).and_return "test"
      OpenChain::S3.should_receive(:download_to_tempfile).with("test", "key").and_yield t
      OpenChain::CustomHandler::ImportExportRegulationParser.should_receive(:process_file).with t, 'iso'

      OpenChain::CustomHandler::ImportExportRegulationParser.process_s3 "key", "iso"
    end
  end

  context :initialize do
    it "should not error for countries that are set up" do
      OpenChain::CustomHandler::ImportExportRegulationParser.new @country
    end

    it "should raise an error for country codes that are not configured" do
      country = Factory(:country)
      expect{OpenChain::CustomHandler::ImportExportRegulationParser.new country}.to raise_error "The Import/Export Regulation Parser is not capable of processing files for '#{country.iso_code}'."
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
    end

    it "should process a TW import file" do
      io = StringIO.new @data
      parser = OpenChain::CustomHandler::ImportExportRegulationParser.new @country
      parser.process io

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

    context "integration test" do
      before :each do
        #Upload the data contents to S3
        @original_tempfile = Tempfile.new('abc')
        @key = "s3_io_#{Time.now.to_f}.txt"
        @original_tempfile.write @data
        @original_tempfile.flush
        
        OpenChain::S3.upload_file OpenChain::S3.bucket_name('test'), @key, @original_tempfile
      end

      after :each do
        begin
          OpenChain::S3.delete OpenChain::S3.bucket_name('test'), @key
        ensure
          @original_tempfile.close!
        end
      end
      
      it "should download a file from S3 and process it" do
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