describe OpenChain::CustomHandler::Vandegrift::KewillEntryStatementValidationRule do 

  let! (:statement) {
    s = DailyStatement.create! statement_number: "12345"
    e = s.daily_statement_entries.create! entry: entry, duty_amount: BigDecimal("10"), fee_amount: BigDecimal("20"), tax_amount: BigDecimal("30"), cvd_amount: BigDecimal("40"), add_amount: BigDecimal("50"), total_amount: BigDecimal("150")
    cotton = e.daily_statement_entry_fees.create! code: "56", amount: BigDecimal("3")
    hmf = e.daily_statement_entry_fees.create! code: "501", amount: BigDecimal("7")
    mpf = e.daily_statement_entry_fees.create! code: "499", amount: BigDecimal("10")

    s
  }

  let (:entry) {
    # Create an entry / statement that is by default valid
    e = Factory(:entry, pay_type: 2, total_duty: BigDecimal("10"), total_fees: BigDecimal("20"), total_taxes: BigDecimal("30"), total_cvd: BigDecimal("40"), total_add: BigDecimal("50"), cotton_fee: BigDecimal("3"), hmf: BigDecimal("7"), mpf: BigDecimal("10"))
    inv = e.commercial_invoices.create! invoice_number: "INV"
    line = inv.commercial_invoice_lines.create! line_number: 1, cvd_duty_amount: BigDecimal("40"), add_duty_amount: BigDecimal("50"), cotton_fee: BigDecimal("3"), hmf: BigDecimal("7"), prorated_mpf: BigDecimal("10")
    tariff = line.commercial_invoice_tariffs.create! duty_amount: BigDecimal("10")

    bi = e.broker_invoices.create! invoice_number: "BROKER INVOICE", source_system: "Alliance"
    bi.broker_invoice_lines.create! charge_code: "0001", charge_description: "DUTY", charge_amount: BigDecimal("150")

    e
  }

  describe "run_validation" do

    it "validates all statement values against entry" do
      expect(subject.run_validation entry).to eq []
    end

    it "errors if Total Duty, Taxes, Fees, Penalties are wrong" do
      # Mocking this because technically if the 5 components of this field are valid then it should also be so (.ie Total Duty, Total Fees, Total Taxes, ADD, CVD)
      expect(entry).to receive(:total_duty_taxes_fees_amount).and_return BigDecimal("1.0")

      expect(subject.run_validation entry).to eq ["The Entry Total Duty, Taxes, Fees & Penalties value of '1.00' does not match the statement amount of '150.00'."]
    end

    it "errors if Total Billed Duty Amount is wrong" do
      entry.broker_invoices.first.broker_invoice_lines.first.update_attributes! charge_amount: BigDecimal("1")

      expect(subject.run_validation entry).to eq ["The Entry Total Billed Duty Amount value of '1.00' does not match the statement amount of '150.00'."]
    end

    it "errors if Total Fees amount is invalid" do
      expect(entry).to receive(:total_fees).and_return BigDecimal("1.0")

      expect(subject.run_validation entry).to eq ["The Entry Total Fees value of '1.00' does not match the statement amount of '20.00'."]
    end

    it "errors if HMF amount is invalid" do
      entry.commercial_invoices.first.commercial_invoice_lines.first.update_attributes! hmf: BigDecimal("1")

      expect(subject.run_validation entry).to eq ["The sum total Commercial Invoice Line HMF amount of '1.00' does not match the statement amount of '7.00'."]
    end

    it "errors if Total HMF is invalid" do
      entry.hmf = BigDecimal("1.0")
      expect(subject.run_validation entry).to eq ["The Entry HMF value of '1.00' does not match the statement amount of '7.00'."]
    end

    it "errors if mpf amount is invalid" do
      entry.commercial_invoices.first.commercial_invoice_lines.first.update_attributes! prorated_mpf: BigDecimal("1")

      expect(subject.run_validation entry).to eq ["The sum total Commercial Invoice Line MPF - Prorated amount of '1.00' does not match the statement amount of '10.00'."]
    end

    it "errors if Total MPF is invalid" do
      entry.mpf = BigDecimal("1.0")
      expect(subject.run_validation entry).to eq ["The Entry MPF value of '1.00' does not match the statement amount of '10.00'."]
    end

    it "errors if cotton fee is invalid" do
      entry.commercial_invoices.first.commercial_invoice_lines.first.update_attributes! cotton_fee: BigDecimal("1")

      expect(subject.run_validation entry).to eq ["The sum total Commercial Invoice Line Cotton Fee amount of '1.00' does not match the statement amount of '3.00'."]
    end

    it "errors if Total Cotton Fee is invalid" do
      entry.cotton_fee = BigDecimal("1.0")
      expect(subject.run_validation entry).to eq ["The Entry Cotton Fee value of '1.00' does not match the statement amount of '3.00'."]
    end

    it "errors if line CVD is invalid" do
      entry.commercial_invoices.first.commercial_invoice_lines.first.update_attributes! cvd_duty_amount: BigDecimal("1")

      expect(subject.run_validation entry).to eq ["The sum total Commercial Invoice Line CVD Duty amount of '1.00' does not match the statement amount of '40.00'."]
    end

    it "errors if Total CVD is invalid" do
      entry.total_cvd = BigDecimal("1.0")

      expect(subject.run_validation entry).to eq ["The Entry Total CVD value of '1.00' does not match the statement amount of '40.00'."]
    end

    it "errors if line ADD is invalid" do
      entry.commercial_invoices.first.commercial_invoice_lines.first.update_attributes! add_duty_amount: BigDecimal("1")

      expect(subject.run_validation entry).to eq ["The sum total Commercial Invoice Line ADD Duty amount of '1.00' does not match the statement amount of '50.00'."]
    end

    it "errors if Total ADD is invalid" do
      entry.total_add = BigDecimal("1.0")

      expect(subject.run_validation entry).to eq ["The Entry Total ADD value of '1.00' does not match the statement amount of '50.00'."]
    end

    it "errors if total taxes is invalid" do
      entry.total_taxes = BigDecimal("1")

      expect(subject.run_validation entry).to eq ["The Entry Total Taxes value of '1.00' does not match the statement amount of '30.00'."]
    end

    it "errors if total duty is invalid" do
      entry.total_duty = BigDecimal("1")

      expect(subject.run_validation entry).to eq ["The Entry Total Duty value of '1.00' does not match the statement amount of '10.00'."]
    end

    it "errors if line duty amount is invalid" do
      entry.commercial_invoices.first.commercial_invoice_lines.first.commercial_invoice_tariffs.first.update_attributes! duty_amount: BigDecimal("1")

      expect(subject.run_validation entry).to eq ["The sum total Commercial Invoice Line Total Duty amount of '1.00' does not match the statement amount of '10.00'."]
    end

  end
end