describe OpenChain::CustomHandler::EddieBauer::EddieBauerCommercialInvoiceParser do

  let (:file_contents) { IO.read 'spec/fixtures/files/eddie_fenix_invoice.csv' }
  let! (:eddie_parts) { Factory(:importer, system_code: "EDDIE")}
  let (:row_arrays) {
    CSV.parse file_contents, col_sep: "|", quote_char: "\007"
  }
  let (:log) { InboundFile.new }

  describe "parse_file" do
    subject { described_class }
    let! (:country) { Factory(:country, iso_code: "CA")}

    it "parse a file and sends invoices" do
      sent_invoices = []
      allow_any_instance_of(OpenChain::CustomHandler::FenixNdInvoiceGenerator).to receive(:generate_and_send) do |inst, invoice|
        sent_invoices << invoice
      end

      data = (file_contents + file_contents)
      subject.parse_file data, log
      # verify the parse is forcing the data encoding to Windows-1252
      expect(data.encoding.name).to eq "Windows-1252"
      expect(sent_invoices.length).to eq 2

      expect(log.company).to eq eddie_parts
    end
  end

  describe "process_ca_invoice_rows" do
    let (:country) { Factory(:country, iso_code: "CA")}
    let! (:eddie) { Factory(:importer, fenix_customer_number: "855157855RM0001")}
    let! (:product) { 
      p = Factory(:product, unique_identifier: "EDDIE-009-5123")
      classification = Factory(:classification, product: p, country: country)
      tariff = Factory(:tariff_record, hts_1: "9876543210", classification: classification)
      p      
    }

    it "parses CSV data into invoice" do
      inv = subject.process_ca_invoice_rows row_arrays

      expect(inv.invoice_number).to eq "328228"
      expect(inv.importer).to eq eddie
      expect(inv.invoice_date).to eq Date.new(2017, 3, 27)
      expect(inv.currency).to eq "USD"
      expect(inv.total_quantity_uom).to eq "CTN"
      expect(inv.total_quantity).to eq BigDecimal("1")
      expect(inv.gross_weight).to eq BigDecimal("12")

      vendor = inv.vendor
      expect(vendor.name).to eq "Eddie Bauer of Canada Corp"
      address = vendor.addresses.first
      expect(address.full_address_array(skip_name: true)).to eq ["6625 Port Road", "Groveport, OH 43125"]

      consignee = inv.consignee
      expect(consignee.name).to eq "EDDIE BAUER STORE R228"
      address = consignee.addresses.first
      expect(address.full_address_array(skip_name: true)).to eq ["1150 ROBSON STREET", "VANCOUVER, BC V6E 1B2"]

      expect(inv.commercial_invoice_lines.length).to eq 2

      line = inv.commercial_invoice_lines.first
      expect(line.part_number).to eq "009-5123"
      expect(line.country_origin_code).to eq "CN"
      expect(line.quantity).to eq 3
      expect(line.unit_price).to eq BigDecimal("9.58")
      expect(line.po_number).to eq "ABCD"
      tariff = line.commercial_invoice_tariffs.first
      expect(tariff.hts_code).to eq "9876543210"
      expect(tariff.tariff_description).to eq "WOMENS MMF KNIT PANT 42% CTN; 26% MODAL; 28% NYLON; 4% OTHER"

      line = inv.commercial_invoice_lines.second
      expect(line.part_number).to eq "019-0019"
      expect(line.country_origin_code).to eq "CN"
      expect(line.quantity).to eq 1
      expect(line.unit_price).to eq BigDecimal("13.41")
      expect(line.po_number).to eq "EFGH"
      tariff = line.commercial_invoice_tariffs.first
      expect(tariff.hts_code).to be_nil
      expect(tariff.tariff_description).to eq "M SHOE TEXTILE UPPER RUBER SOLE"
    end

    context "rollup scenarios" do

      after(:each) do 
        inv = subject.process_ca_invoice_rows row_arrays
        expect(inv.commercial_invoice_lines.length).to eq 3
      end

      it "does not combine rows if description differs" do
        row_arrays[1][6] = "Description"
      end

      it "does not combine rows if unit price differs" do
        row_arrays[1][22] = "1.99"
      end

      it "does not combine rows if country of origin differs" do
        row_arrays[1][34] = "GB"
      end
    end

    it "uses a sku suffix to determine if style is different from previous line" do
      row_arrays[1][5] = "009-5123-100-1004-A"
      inv = subject.process_ca_invoice_rows row_arrays
      expect(inv.commercial_invoice_lines.length).to eq 3

      line = inv.commercial_invoice_lines.first
      expect(line.part_number).to eq "009-5123A"
    end
  end

  describe "process_us_invoice_rows" do

    let (:country) { Factory(:country, iso_code: "US")}
    let! (:product) { 
      p = Factory(:product, unique_identifier: "EDDIE-009-5123")
      classification = Factory(:classification, product: p, country: country)
      tariff = Factory(:tariff_record, hts_1: "9876543210", classification: classification)
      p      
    }

    it "populates a kewill entry object" do
      entry = subject.process_us_invoice_rows row_arrays
      expect(entry).not_to be_nil

      expect(entry.customer).to eq "EBCC"
      expect(entry.invoices.length).to eq 1

      inv = entry.invoices.first
      expect(inv.invoice_number).to eq "328228"
      expect(inv.invoice_date).to eq Date.new(2017, 3, 27)

      # there is no detail rollup for US
      expect(inv.invoice_lines.length).to eq 3
      line = inv.invoice_lines.first

      expect(line.part_number).to eq "009-5123"
      expect(line.country_of_origin).to eq "CN"
      expect(line.pieces).to eq 2
      expect(line.unit_price).to eq BigDecimal("9.58")
      expect(line.foreign_value).to eq BigDecimal("19.16")
      expect(line.po_number).to eq "ABCD"
      expect(line.hts).to eq "9876543210"
      expect(line.mid).to eq "MID"
      expect(line.seller_mid).to eq "MID"
      expect(line.buyer_customer_number).to eq "EBCC"
    end
  end

  describe "process_and_send_invoice" do

    it "processes a CA file using proper workflow" do
      invoice = instance_double(CommercialInvoice)
      expect(subject).to receive(:process_ca_invoice_rows).with(row_arrays).and_return invoice
      expect_any_instance_of(OpenChain::CustomHandler::FenixNdInvoiceGenerator).to receive(:generate_and_send).with invoice

      subject.process_and_send_invoice row_arrays, log
    end

    it "processes a US file using proper workflow" do
      # Make this a US file
      row_arrays.first[22] = "US"

      # create a dummy entry to use ot make sure the file is named correctly
      entry = described_class::CiLoadEntry.new
      entry.invoices = []
      invoice = described_class::CiLoadInvoice.new
      entry.invoices << invoice
      invoice.invoice_number = "INV"


      expect(subject).to receive(:process_us_invoice_rows).with(row_arrays).and_return entry
      expect(subject).to receive(:generate_xls_to_google_drive).with("EDDIE CI Load/INV.xls", entry)

      subject.process_and_send_invoice row_arrays, log
    end

    it "fails if an unknown country code is encountered" do
      # Not US or CA, so fails.
      row_arrays.first[22] = "XX"

      expect{subject.process_and_send_invoice row_arrays, log}.to raise_error "Unexpected Import Country value received: 'XX'."
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "Unexpected Import Country value received: 'XX'."
    end
  end
end