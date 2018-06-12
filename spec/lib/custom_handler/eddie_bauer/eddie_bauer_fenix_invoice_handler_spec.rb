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
    let (:custom_file) { 
      cf = double("Custom File")
      allow(cf).to receive(:attached).and_return cf
      allow(cf).to receive(:path).and_return "file.txt"
      allow(cf).to receive(:bucket).and_return "bucket"
      allow(cf).to receive(:attached_file_name).and_return "file.txt"

      cf
    }
    let (:importer) { Factory(:company, fenix_customer_number: "855157855RM0001", importer: true) }
    let (:tempfile) {
      tempfile = Tempfile.new ['temp', '.txt']
      tempfile.binmode 
      # Add a quotation mark to make sure we're disabling the quote handling, and send invalid UTF-8 data to make sure we're using 
      # the correct encoding
      tempfile << " |0309018      |2014-03-10| |001-5434 |BD| |WP TRAIL TIGHT \" PANT      |0000010|000022.62|0309018| | | | | | | |     \n"
      tempfile.flush
      tempfile.rewind
      tempfile
    }
    subject { described_class.new(nil) }

    before :each do
      importer
    end

    after :each do 
      tempfile.close! if tempfile && !tempfile.closed?
    end

    it "parses an Eddie pipe delimited file and creates an invoice" do
      expect(OpenChain::S3).to receive(:download_to_tempfile).with('bucket', "file.txt").and_yield tempfile
      subject.parse custom_file, true
      # all we really care about is that an invoice was created, the rest is tested in the actual fenix handler
      inv = CommercialInvoice.where(invoice_number: "0309018").first
      expect(inv).to_not be_nil

      t = inv.commercial_invoice_lines.first.commercial_invoice_tariffs.first
      # This is just how translating the non-breaking spaces above from Windows-1252 to UTF-8 breaks down
      # It's more just an issue of how copy-paste from one document to another works.  In a real document
      # this would work better and these would be spaces.
      expect(t.tariff_description).to eq "WP TRAIL TIGHT \" PANTÂ Â Â Â Â "
    end
  end
end