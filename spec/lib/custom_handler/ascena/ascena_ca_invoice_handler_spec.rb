describe OpenChain::CustomHandler::Ascena::AscenaCaInvoiceHandler do
  describe 'process' do
    before :each do
      @cf = double("Custom File")
      allow(@cf).to receive(:attached).and_return @cf
      allow(@cf).to receive(:path).and_return "path/to/file.csv"
      allow(@cf).to receive(:attached_file_name).and_return "file.csv"

      @user = FactoryBot(:master_user)
      @h = described_class.new @cf
    end

    it "should parse the file" do
      expect(@h).to receive(:parse).with(@cf.attached.path).and_return []
      @h.process @user

      expect(@user.messages.length).to eq 1
      expect(@user.messages.first.subject).to eq "Ascena Invoice File Processing Completed"
      expect(@user.messages.first.body).to eq "Ascena Invoice File '#{@cf.attached_file_name}' has finished processing."
    end

    it "should catch handler errors and store message to user" do
      expect(@h).to receive(:parse).with(@cf.attached.path).and_raise described_class::AscenaCaInvoiceHandlerError.new("ERROR")

      @h.process(@user)

      expect(@user.messages.first.subject).to eq "Ascena Invoice File Processing Completed With Errors"
      expect(@user.messages.first.body).to eq "Ascena Invoice File '#{@cf.attached_file_name}' has finished processing.<br>Unrecoverable errors were encountered while processing this file.<br>ERROR"
    end

    it "should catch and re-throw other errors" do
      expect(@h).to receive(:parse).with(@cf.attached.path).and_raise "ERROR"

      expect { @h.process(@user) }.to raise_error "ERROR"

      expect(@user.messages.first.subject).to eq "Ascena Invoice File Processing Completed With Errors"
      expect(@user.messages.first.body).to eq "Ascena Invoice File '#{@cf.attached_file_name}' has finished processing.<br>Unrecoverable errors were encountered while processing this file.<br>ERROR"
    end
  end

  describe "parse" do
    let(:handler) { described_class.new "some file" }
    let(:temp_file) { double "temp file" }
    let(:s3_path) { "path/to/s3_file.csv" }

    before do
      allow(OpenChain::S3).to receive(:download_to_tempfile).with('chain-io', s3_path).and_yield temp_file
    end

    it "parses the input file if it's a .csv" do
      expect(handler).to receive(:parse_csv).with(temp_file)
      handler.parse s3_path
    end

    it "raises an error and doesn't parse the file if it isn't a .csv" do
      s3_path = "path/to/s3_file.xls"
      expect(handler).not_to receive(:parse_csv)
      expect { handler.parse s3_path }.to raise_error described_class::AscenaCaInvoiceHandlerError, "No CI Upload processor exists for .xls file types."
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

      @co = with_fenix_id(FactoryBot(:importer), "858053119RM0001")
      @ci = FactoryBot(:commercial_invoice, entry: nil, invoice_number: @row1[0], importer_id: @co.id)
      @handler = described_class.new "some file"
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

        expect(ci.importer_id).to eq @co.id
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
        CommercialInvoice.destroy_all
      end

      it "replaces invoice lines if invoice already exists" do
        old_cil = FactoryBot(:commercial_invoice_line, commercial_invoice: @ci, part_number: @row1[7..9].join('-'),
                          country_origin_code: @row1[23], quantity: @row1[29], value: @row1[30])
        old_cit = FactoryBot(:commercial_invoice_tariff, commercial_invoice_line: old_cil, hts_code: @row1[27].delete('.'))
      end

    end

    describe "parse_invoice_line" do
      it "translates csv row into corresponding ActiveRecord objects" do
        invoice_with_built_line = @handler.parse_invoice_line @row1, @ci
        cil = invoice_with_built_line.commercial_invoice_lines.first
        cit = cil.commercial_invoice_tariffs.first

        expect(cil.part_number).to eq "1918-619-1"
        expect(cil.country_origin_code).to eq "CN"
        expect(cil.quantity).to eq 4
        expect(cil.value).to eq 7.4
        expect(cit.hts_code).to eq "3304100000"
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
        expect(@handler.convert_coo 'ABC').to eq 'ABC'
      end
    end

    describe "get_importer_id" do
      let! (:importer) { with_fenix_id(FactoryBot(:company), "123456789") }

      it "looks up importer_id using Fenix ID" do
        expect(@handler.get_importer_id("123456789")).to eq importer.id
      end

      it "throws exception if Fenix ID not found" do
        expect { @handler.get_importer_id("111111111") }.to raise_error("Fenix ID 111111111 not found!")
      end
    end

  end

end
