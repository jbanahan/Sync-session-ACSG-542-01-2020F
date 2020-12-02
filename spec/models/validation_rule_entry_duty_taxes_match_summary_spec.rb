describe ValidationRuleEntryDutyTaxesMatchSummary do

  describe "run_validation" do
    let (:entry) {
      e = create(:entry, total_duty: 150.1, mpf: 25.5, hmf: 10.49, cotton_fee: 0.99)
    }

    let (:commercial_invoice) {
      entry.commercial_invoices.create! invoice_number: "INVOICE"
    }

    let! (:invoice_line_1) {
      line = commercial_invoice.commercial_invoice_lines.create! prorated_mpf: BigDecimal("25"), hmf: BigDecimal("10.49"), cotton_fee: BigDecimal("0.5")
      line.commercial_invoice_tariffs.create! duty_amount: BigDecimal("100")
      line.commercial_invoice_tariffs.create! duty_amount: BigDecimal("25")

      line
    }

    let! (:invoice_line_2) {
      line = commercial_invoice.commercial_invoice_lines.create! prorated_mpf: BigDecimal("0.5"), cotton_fee: BigDecimal("0.49")
      line.commercial_invoice_tariffs.create! duty_amount: BigDecimal("25.1")

      line
    }

    it "doesn't return errors if sums are valid" do
      expect(subject.run_validation entry).to be_blank
    end

    it "detects incorrect duty amount" do
      invoice_line_1.commercial_invoice_tariffs.second.update_attributes! duty_amount: BigDecimal("50")

      expect(subject.run_validation entry).to eq ["Invoice Tariff duty amounts should equal the 7501 Total Duty amount $150.10 but it was $175.10."]
    end

    it "detects incorrect MPF amount" do
      invoice_line_1.update_attributes! prorated_mpf: BigDecimal("30")

      expect(subject.run_validation entry).to eq ["Invoice Line MPF amount should equal the 7501 MPF amount $25.50 but it was $30.50."]
    end

    it "detects incorrect HMF amount" do
      invoice_line_1.update_attributes! hmf: BigDecimal("10.50")

      expect(subject.run_validation entry).to eq ["Invoice Line HMF amount should equal the 7501 HMF amount $10.49 but it was $10.50."]
    end

    it "detects incorrect Cotton Fee amount" do
      invoice_line_1.update_attributes! cotton_fee: BigDecimal("0.51")

      expect(subject.run_validation entry).to eq ["Invoice Line Cotton Fee amount should equal the 7501 Cotton Fee amount $0.99 but it was $1.00."]
    end

    it "detects all errors" do
      invoice_line_1.commercial_invoice_tariffs.second.update_attributes! duty_amount: BigDecimal("50")
      invoice_line_1.update_attributes! prorated_mpf: BigDecimal("30"), hmf: BigDecimal("10.50"), cotton_fee: BigDecimal("0.51")

      errors = subject.run_validation entry

      expect(errors).to include "Invoice Tariff duty amounts should equal the 7501 Total Duty amount $150.10 but it was $175.10."
      expect(errors).to include "Invoice Line MPF amount should equal the 7501 MPF amount $25.50 but it was $30.50."
      expect(errors).to include "Invoice Line HMF amount should equal the 7501 HMF amount $10.49 but it was $10.50."
      expect(errors).to include "Invoice Line Cotton Fee amount should equal the 7501 Cotton Fee amount $0.99 but it was $1.00."
    end

    it "doesn't error if all values are nil" do
      entry = create(:entry)
      entry.commercial_invoices.create! invoice_number: "INVOICE"
      line = commercial_invoice.commercial_invoice_lines.create!
      tariff = line.commercial_invoice_tariffs.create!

      expect(subject.run_validation entry).to be_blank
    end
  end
end