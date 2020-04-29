describe OpenChain::CustomHandler::Vandegrift::FtzCiLoadParser do
  subject { described_class.new nil }

  let (:row_data) {
    [
      ["12345", "CUST", "INV-123", "2015-01-01", "US", "PART-1", 12.0, "MID12345", "1234.56.7890", "N", 22.50, 10, 35, 50.5, "Purchase Order", 12, "21.50", "123.45", "19", "A+", "BuyerCustNo", "SellerMID", "X", 100.2, "P", "20190315"]
    ]
  }

  describe "parse_entry_header" do
    it 'parses a row to invoice line object' do
      l = subject.parse_invoice_line nil, nil, row_data.first

      expect(l.ftz_quantity).to eq BigDecimal("100.2")
      expect(l.ftz_zone_status).to eq "P"
      expect(l.ftz_priv_status_date).to eq Date.new(2019, 3, 15)
    end
  end
end
