describe Invoice do 

  describe "calculate_and_set_invoice_totals" do
    let (:invoice) {
      i = Invoice.new
      i.invoice_lines.build air_sea_discount: BigDecimal("1"), early_pay_discount: BigDecimal("2"), trade_discount: BigDecimal("3"), middleman_charge: BigDecimal("4"), value_foreign: BigDecimal("100"), value_domestic: BigDecimal("200")
      i.invoice_lines.build air_sea_discount: BigDecimal("5"), early_pay_discount: BigDecimal("6"), trade_discount: BigDecimal("7"), middleman_charge: BigDecimal("8"), value_foreign: BigDecimal("300"), value_domestic: BigDecimal("400")

      i
    }

    it "sums total amounts from line and sets into header" do
      invoice.calculate_and_set_invoice_totals

      expect(invoice.total_discounts).to eq 24
      expect(invoice.total_charges).to eq 12
      expect(invoice.invoice_total_foreign).to eq 400
      expect(invoice.invoice_total_domestic).to eq 600
    end

    it "handles no lines" do
      invoice.invoice_lines = []
      invoice.calculate_and_set_invoice_totals

      expect(invoice.total_discounts).to eq 0
      expect(invoice.total_charges).to eq 0
      expect(invoice.invoice_total_foreign).to eq 0
      expect(invoice.invoice_total_domestic).to eq 0
    end

    it "handles missing value foreign / domestic amounts" do
      l = invoice.invoice_lines.first
      l.value_domestic = nil
      l.value_foreign = nil

      invoice.calculate_and_set_invoice_totals
      expect(invoice.invoice_total_foreign).to eq 300
      expect(invoice.invoice_total_domestic).to eq 400
    end
  end
end