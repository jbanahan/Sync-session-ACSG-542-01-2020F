describe OpenChain::CustomHandler::Vandegrift::HmCiLoadParser do
  subject { described_class.new nil }

  describe "invalid_row?" do
    it "validates a good row" do
      expect(subject.invalid_row? ["FILE", nil, "INV"]).to be_falsey
    end

    it "invalidates row missing file number" do
      expect(subject.invalid_row? [nil, nil, "INV"]).to be_truthy
    end

    it "invalidates row missing invoice number" do
      expect(subject.invalid_row? ["File", nil, "   "]).to be_truthy
    end
  end

  describe "file_number_invoice_number_columns" do
    it "returns expected values" do
      expect(subject.file_number_invoice_number_columns).to eq({file_number: 0, invoice_number: 2})
    end
  end

  describe "parse_entry_header" do
    it "parses a row to an entry header object" do
      entry = subject.parse_entry_header [1234]
      expect(entry.file_number).to eq "1234"
      expect(entry.customer).to eq "HENNE"
      expect(entry.invoices.length).to eq 0
    end

    it "parses a row to invoice header object" do
      invoice = subject.parse_invoice_header nil, [nil, nil, "INV", nil, "-1.23", "3.45"]
      expect(invoice.invoice_number).to eq "INV"
      expect(invoice.invoice_date).to eq nil
      expect(invoice.non_dutiable_amount).to eq BigDecimal("1.23") # validate we're storing the abs value
      expect(invoice.add_to_make_amount).to eq BigDecimal("3.45")
      expect(invoice.invoice_lines.length).to eq 0
    end

    it 'parses a row to invoice line object' do
      l = subject.parse_invoice_line nil, nil, [nil, nil, nil, "1.23", nil, nil, nil, "1234567890", "CN", "5", "10", "2", "100", "MID", "PART", "10", "BuyerCustNo", "SellerMID", "Cotton", "SPI"]

      expect(l.country_of_origin).to eq "CN"
      expect(l.gross_weight).to eq BigDecimal("100")
      expect(l.hts).to eq "1234567890"
      expect(l.foreign_value).to eq BigDecimal("1.23")
      expect(l.quantity_1).to eq BigDecimal("5")
      expect(l.quantity_2).to eq BigDecimal("10")
      expect(l.mid).to eq "MID"
      expect(l.cartons).to eq BigDecimal("2")
      expect(l.part_number).to eq "PART"
      expect(l.pieces).to eq BigDecimal("10")
      expect(l.buyer_customer_number).to eq "BuyerCustNo"
      expect(l.seller_mid).to eq "SellerMID"
      expect(l.cotton_fee_flag).to eq "Cotton"
      expect(l.spi).to eq "SPI"
    end
  end
end
