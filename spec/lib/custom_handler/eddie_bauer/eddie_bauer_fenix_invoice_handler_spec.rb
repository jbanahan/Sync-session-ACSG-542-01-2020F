describe OpenChain::CustomHandler::EddieBauer::EddieBauerFenixInvoiceHandler do

  describe "prep_header_row" do
    it "adds importer info and country of origin to the row" do
      expect(described_class.new(nil).prep_header_row []).to eq [
        "855157855RM0001", "", "", "UOH", "", "", "", "", "", "", "", "", ""
      ]
    end
  end

  describe "prep_line_row" do

    before :each do 
      @p = Factory(:tariff_record, hts_1: "1234.56.7890", 
        classification: Factory(:classification, 
          country: Factory(:country, :iso_code => "CA"),
          product: Factory(:product, unique_identifier: "EDDIE-12345")
        )
      ).product

    end

    it "adds hts number and translates US to UOH" do
      expect(described_class.new(nil).prep_line_row ["", "", "", "", "12345", "US"]).to eq [
        "855157855RM0001", "", "", "UOH", "12345", "UOH", "1234567890", "", "", "", "", "", ""
      ]
    end
  end

  describe "parse" do
    before :each do
      @importer = Factory(:company, fenix_customer_number: "855157855RM0001", importer: true)
      @tempfile = Tempfile.new ['temp', '.txt']
      @tempfile.binmode 
      # Add a quotation mark to make sure we're disabling the quote handling
      @tempfile << "header1|\n |0309018      |2014-03-10| |001-5434 |BD| |MENS WVN LAMINATED POLY JKT 1\"                                         |0000010|000022.62|0309018| | | | | | | |     \n"
      @tempfile.flush
      @tempfile.rewind

      OpenChain::S3.should_receive(:download_to_tempfile).with('chain-io', "path/to/file.txt").and_yield @tempfile
    end

    after :each do 
      @tempfile.close!
    end

    it "parses an Eddie pipe delimited file and creates an invoice" do
      described_class.new(nil).parse "path/to/file.txt", true
      # all we really care about is that an invoice was created, the rest is tested in the actual fenix handler
      expect(CommercialInvoice.where(invoice_number: "0309018").first).to_not be_nil
    end
  end
end