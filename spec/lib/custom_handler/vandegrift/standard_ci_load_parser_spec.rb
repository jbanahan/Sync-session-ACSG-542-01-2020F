describe OpenChain::CustomHandler::Vandegrift::StandardCiLoadParser do
  subject { described_class.new nil }

  let (:row_data) {
    [
      ["12345", "CUST", "INV-123", "2015-01-01", "US", "PART-1", 12.0, "MID12345", "1234.56.7890", "N", 22.50, 10, 35, 50.5, "Purchase Order", 12, "21.50", "123.45", "19", "A+", "BuyerCustNo", "SellerMID", "X"]
    ]
  }

  describe "invalid_row?" do
    it "validates a good row" do
      expect(subject.invalid_row? ["FILE", "CUST", "INV"]).to be_falsey
    end

    it "invalidates row missing file number" do
      expect(subject.invalid_row? [nil, "CUST", "INV"]).to be_truthy
    end

    it "invalidates row missing customer number" do
      expect(subject.invalid_row? ["FILE", "", "INV"]).to be_truthy
    end

    it "invalidates row missing invoice number" do
      expect(subject.invalid_row? ["File", "CUST", "   "]).to be_truthy
    end
  end

  describe "file_number_invoice_number_columns" do
    it "returns expected values" do
      expect(subject.file_number_invoice_number_columns).to eq({file_number: 0, invoice_number: 2})
    end
  end

  describe "parse_entry_header" do
    it "parses a row to an entry header object" do
      entry = subject.parse_entry_header [1234, "CUST"]
      expect(entry.file_number).to eq "1234"
      expect(entry.customer).to eq "CUST"
      expect(entry.invoices.length).to eq 0
    end

    it "parses a row to invoice header object" do
      invoice = subject.parse_invoice_header nil, [nil, nil, "INV", "2016-02-01"]
      expect(invoice.invoice_number).to eq "INV"
      expect(invoice.invoice_date).to eq Date.new(2016, 2, 1)
      expect(invoice.invoice_lines.length).to eq 0
    end

    it 'parses a row to invoice line object' do
      l = subject.parse_invoice_line nil, nil, row_data.first

      expect(l.part_number).to eq "PART-1"
      expect(l.country_of_origin).to eq "US"
      expect(l.gross_weight).to eq BigDecimal("50.5")
      expect(l.pieces).to eq BigDecimal("12")
      expect(l.hts).to eq "1234567890"
      expect(l.foreign_value).to eq BigDecimal("22.50")
      expect(l.quantity_1).to eq BigDecimal("10")
      expect(l.quantity_2).to eq BigDecimal("35")
      expect(l.po_number).to eq "Purchase Order"
      expect(l.first_sale).to eq BigDecimal("21.50")
      expect(l.department).to eq BigDecimal("19")
      expect(l.spi).to eq "A+"
      expect(l.add_to_make_amount).to eq BigDecimal("123.45")
      expect(l.non_dutiable_amount).to be_nil
      expect(l.cotton_fee_flag).to eq "N"
      expect(l.mid).to eq "MID12345"
      expect(l.cartons).to eq BigDecimal("12")
      expect(l.buyer_customer_number).to eq "BuyerCustNo"
      expect(l.seller_mid).to eq "SellerMID"
      expect(l.spi2).to eq "X"
    end

    it "handles negative value in col 17 as non-dutiable charge" do
      row_data.first[17] = "-123.45"

      l = subject.parse_invoice_line nil, nil, row_data.first

      expect(l.add_to_make_amount).to be_nil
      expect(l.non_dutiable_amount).to eq BigDecimal("123.45")
    end
  end
end
