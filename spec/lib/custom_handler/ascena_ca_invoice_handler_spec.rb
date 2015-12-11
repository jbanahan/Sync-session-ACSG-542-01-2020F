require 'spec_helper'

describe OpenChain::CustomHandler::AscenaCaInvoiceHandler do
  describe 'process' do
    before :each do 
      @cf = double("Custom File")
      @cf.stub(:attached).and_return @cf
      @cf.stub(:path).and_return "path/to/file.csv"
      @cf.stub(:attached_file_name).and_return "file.csv"

      @user = Factory(:master_user)
      @h = described_class.new @cf
    end

    it "should parse the file" do
      @h.should_receive(:parse).with(@cf.attached.path).and_return []
      @h.process @user

      @user.messages.length.should eq 1
      @user.messages.first.subject.should eq "Ascena Invoice File Processing Completed"
      @user.messages.first.body.should eq "Ascena Invoice File '#{@cf.attached_file_name}' has finished processing."
    end

    it "should put errors into the user messages" do
      @h.should_receive(:parse).with(@cf.attached.path).and_return ["Error1", "Error2"]

      @h.process @user

      @user.messages.length.should eq 1
      @user.messages.first.subject.should eq "Ascena Invoice File Processing Completed With Errors"
      @user.messages.first.body.should eq "Ascena Invoice File '#{@cf.attached_file_name}' has finished processing.\n\nError1\nError2"
    end

    it "should handle uncaught errors" do
      @h.should_receive(:parse).with(@cf.attached.path).and_raise "Error"

      expect {@h.process(@user)}.to raise_error "Error"

      @user.messages.first.subject.should eq "Ascena Invoice File Processing Completed With Errors"
      @user.messages.first.body.should eq "Ascena Invoice File '#{@cf.attached_file_name}' has finished processing.\n\nUnrecoverable errors were encountered while processing this file.  These errors have been forwarded to the IT department and will be resolved."
    end
  end

  describe "parse" do
    it "should call s3_to_db and return any errors" do
      handler = described_class.new "file.csv" # dummy input 
      s3_path = "path/to/s3_file"
      handler.should_receive(:s3_to_db).with(s3_path).and_raise "ERROR"
      expect(handler.parse s3_path).to eq ["Failed to process invoice due to the following error: 'ERROR'."]
    end
  end

  describe "s3_to_db" do
    before :each do
      @handler = described_class.new "file.csv" # dummy input 
    end

    it "parses the input file if it's a .csv" do
      s3_path = "path/to/s3_file.csv"
      temp_file = double()
      OpenChain::S3.should_receive(:download_to_tempfile).with('chain-io', s3_path).and_yield temp_file
      @handler.should_receive(:parse_csv).with(temp_file)
      @handler.s3_to_db s3_path
    end

    it "raises an error and doesn't parse the file if it isn't a .csv" do
      s3_path = "path/to/s3_file.xls"
      @handler.should_not_receive(:parse_csv)
      expect{ @handler.s3_to_db s3_path }.to raise_error "No CI Upload processor exists for .xls file types."
    end
  end

  context "csv parsing" do
    before :each do
      @header = ["INVOICE #", "TYPE, LOAD", "SHIP STORE", "DEPT", "CLASS", "VENDOR", "STYLE", 
                 "COLOR", "SIZE", "CARTON#", "SKU", "CHK", "EXPSKU", "DESC1", "DESC2", "DESC3", 
                 "DESC4", "COST", "RETAIL", "SUG PRC", "SUG*TRF PRICE", "TRF PRC %", "COO", "PIECE COST", 
                 "PIECE COST %", "WEIGHT", "CA HTS", "NUM PIECES", "TOTAL UNITS", "TOTAL DOLLARS", 
                 "COMPOSITION1", "COMPOSITION2", "COMPOSITION3", "COMPOSITION4", "COMPOSITION5", 
                 "COMPOSITION6", "COMMENTS1", "COMMENTS2", "COMMENTS3", "COMMENTS4"]
      
      @row1 = ["CA201512031", "M", "114206", "1802", "19", "169", "84809", "1918", "619", "1", "99999990107435700", 
               "1904579", "7", "19045797", "6PC SET-ELF SHELF W/KEYCH", " ", " ", " ", "1.8", "6.63", "9.9", "1.85", 
               "0.04", "CN", "1.3", "72.46", "0.24", "3304.10.0000", "0", "4", "7.4", "NA", " ", " ", " ", " ", " ", 
               "N024988", " ", " ", "*", "1.75", "0.03", "0.07"]

      @row2 = ["CA201512031", "M", "114206", "1819", "21", "566", "76231", "2113", "619", "1", "1234560002576100", 
               "9012924", "7", "90129247", "KEEP OUT TREASURE CHEST", " ", " ", " ", "9.45", "19.9", "19.9", "13.34", 
               "0.04", "CN", "9.45", "0", "0.9", "3924.90.0099", "0", "4", "53.36", "Plastic", " ", " ", " ", " ", " ", 
               " ", " ", " ", " ", "12.64", "0.19", "0.51"]

      @ci = Factory(:commercial_invoice, entry: nil, invoice_number: @row1[0], importer_id: '1137') 
      @handler = described_class.new "file.csv" # dummy input
    end

    describe "parse_csv" do
      after(:each) do
        Tempfile.open(['invoices', '.csv']) do |tempfile|
          CSV.open(tempfile, "wb") do |csv|
            csv << @header
            csv << @row1  
            csv << @row2  
          end
          @handler.parse_csv tempfile
        end    
        ci = CommercialInvoice.first
        cil_first = CommercialInvoiceLine.first
        cit_first = CommercialInvoiceTariff.first

        expect(ci.importer_id).to eq 1137
        expect(ci.invoice_number).to eq "CA201512031"
        expect(cil_first.part_number).to eq "1918-619-1"
        expect(cil_first.country_origin_code).to eq "CN"
        expect(cil_first.quantity).to eq 4
        expect(cil_first.value).to eq 7.4
        expect(cit_first.hts_code).to eq "3304100000"

        expect(cit_first.commercial_invoice_line).to eq cil_first
        expect(cil_first.commercial_invoice).to eq ci

        cil_second = CommercialInvoiceLine.last
        cit_second = CommercialInvoiceTariff.last

        expect(cil_second.part_number).to eq "2113-619-1"
        expect(cil_second.country_origin_code).to eq "CN"
        expect(cil_second.quantity).to eq 4
        expect(cil_second.value).to eq 53.36
        expect(cit_second.hts_code).to eq "3924900099"

        expect(cit_second.commercial_invoice_line).to eq cil_second
        expect(cil_second.commercial_invoice).to eq ci
        
        expect(CommercialInvoiceLine.count).to eq 2
        expect(CommercialInvoiceTariff.count).to eq 2
      end

      it "translates csv rows into corresponding ActiveRecord objects" do
        # intentionally blank
      end

      it "replaces invoice lines if invoice already exists" do 
        old_cil = Factory(:commercial_invoice_line, commercial_invoice: @ci, part_number: @row1[7..9].join('-'), 
                          country_origin_code: @row1[23], quantity: @row1[29], value: @row1[30])
        old_cit = Factory(:commercial_invoice_tariff, commercial_invoice_line: old_cil, hts_code: @row1[27].delete('.')) 
      end

    end

    describe "parse_invoice_line" do
      it "translates csv row into corresponding ActiveRecord objects" do
        @handler.parse_invoice_line @row1, @ci

        cil = CommercialInvoiceLine.last
        cit = CommercialInvoiceTariff.last
        
        expect(cil.part_number).to eq "1918-619-1"
        expect(cil.country_origin_code).to eq "CN"
        expect(cil.quantity).to eq 4
        expect(cil.value).to eq 7.4
        expect(cit.hts_code).to eq "3304100000"

        expect(cit.commercial_invoice_line).to eq cil
        expect(cil.commercial_invoice).to eq @ci
      end      

      it "throws an exception if tariff number has wrong format" do
        bad_row = @row1
        bad_row[27] = "foo"
        
        expect {@handler.parse_invoice_line bad_row, @ci}.to raise_error("Tariff number has wrong format!")
        expect(CommercialInvoiceLine.count).to eq 0
        expect(CommercialInvoiceTariff.count).to eq 0
      end

      it "throws an exception if invoice number has wrong format" do
        bad_row = @row1
        bad_row[0] = "foo"

        expect {@handler.parse_invoice_line bad_row, @ci}.to raise_error("Invoice number has wrong format!")
        expect(CommercialInvoiceLine.count).to eq 0
        expect(CommercialInvoiceTariff.count).to eq 0     
      end 

    end

    describe "get_invoice_number" do
      it "returns invoice number from header of csv" do
        Tempfile.open(['invoices', '.csv']) do |tempfile|
          CSV.open(tempfile, "wb") do |csv|
            csv << @header
            csv << @row1  
            csv << @row2  
          end
          expect(@handler.get_invoice_number tempfile).to eq 'CA201512031'
        end    
      end
    end

    describe "convert_coo" do
      it "converts 3-letter country-of-origin codes to 'US' and leaves others unchanged" do
        expect(@handler.convert_coo 'UCA').to eq 'US'
        expect(@handler.convert_coo 'ID').to eq 'ID'
      end
    end
  
  end

end