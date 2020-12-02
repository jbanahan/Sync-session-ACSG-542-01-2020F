describe CommercialInvoiceLine do
  describe "duty_plus_fees_amount" do
    it "sums all duty and fees for a line" do
      line = described_class.new prorated_mpf: BigDecimal("1"), hmf: BigDecimal("2"), cotton_fee: BigDecimal("3")
      line.commercial_invoice_tariffs.build duty_amount: BigDecimal("4")
      line.commercial_invoice_tariffs.build duty_amount: BigDecimal("5")

      expect(line.duty_plus_fees_amount).to eq BigDecimal "15"
    end

    it "handles nil values in all fields" do
      line = described_class.new
      line.commercial_invoice_tariffs.build

      expect(line.duty_plus_fees_amount).to eq BigDecimal "0"
    end
  end

  describe "total_duty" do
    it "sum duty for line" do
      line = described_class.new
      line.commercial_invoice_tariffs.build duty_amount: BigDecimal("4")
      line.commercial_invoice_tariffs.build duty_amount: BigDecimal("5")

      expect(line.total_duty).to eq BigDecimal "9"
    end
  end

  describe "total_supplemental_tariff" do
    it "sums specified field for chapter 99 tariffs" do
      line = create(:commercial_invoice_line)
      create(:commercial_invoice_tariff, commercial_invoice_line: line, hts_code: "123456789", duty_amount: 10)
      create(:commercial_invoice_tariff, commercial_invoice_line: line, hts_code: "990234567", duty_amount: 12)
      create(:commercial_invoice_tariff, commercial_invoice_line: line, hts_code: "992345678", duty_amount: 13)
      create(:commercial_invoice_tariff, commercial_invoice_line: line, hts_code: "992345678", duty_amount: nil)

      expect(line.total_supplemental_tariff(:duty_amount)).to eq 25
    end
  end

  describe "supplemental_tariffs" do
    it "returns associated chapter 99 tariffs" do
      line = create(:commercial_invoice_line)
      create(:commercial_invoice_tariff, commercial_invoice_line: line, hts_code: "123456789")
      tariff2 = create(:commercial_invoice_tariff, commercial_invoice_line: line, hts_code: "990234567")
      tariff3 = create(:commercial_invoice_tariff, commercial_invoice_line: line, hts_code: "992345678")

      expect(line.supplemental_tariffs).to contain_exactly(tariff2, tariff3)
    end
  end

  describe "total_fees" do
    it "sums fees for line" do
      expect(described_class.new(prorated_mpf: BigDecimal("1"),
                                 hmf: BigDecimal("2"), cotton_fee: BigDecimal("3"),
                                 other_fees: BigDecimal("7")).total_fees).to eq BigDecimal("13")
    end
  end

  describe "total_entered_value" do
    it "sums entered value for all tariff lines" do
      line = described_class.new
      line.commercial_invoice_tariffs.build entered_value: BigDecimal("4")
      line.commercial_invoice_tariffs.build entered_value: BigDecimal("5")

      expect(line.total_entered_value).to eq BigDecimal("9")
    end
  end

  describe "duty_plus_fees_add_cvd_amounts" do
    it "calculates duty plus all fees" do
      line = described_class.new prorated_mpf: BigDecimal("1"),
                                 hmf: BigDecimal("2"),
                                 cotton_fee: BigDecimal("3"),
                                 cvd_duty_amount: BigDecimal("10"),
                                 add_duty_amount: BigDecimal("20")
      line.commercial_invoice_tariffs.build duty_amount: BigDecimal("4")
      line.commercial_invoice_tariffs.build duty_amount: BigDecimal("5")

      expect(line.duty_plus_fees_add_cvd_amounts).to eq BigDecimal("45")
    end
  end

  describe "first_sale_savings" do
    let!(:line) do
      create(:commercial_invoice_line, contract_amount: 500, value: 200,
                                        commercial_invoice_tariffs: [create(:commercial_invoice_tariff, duty_amount: 30, entered_value: 10)])
    end

    it "calculates first sale savings when contract amount isn't zero or nil" do
      expect(line.first_sale_savings).to eq 900
      # amount - value * duty_amount / entered_value
    end

    it "returns 0 when contract amount is 0" do
      line.update(contract_amount: 0)
      expect(line.first_sale_savings).to eq 0
    end

    it "returns 0 when contract amount is nil" do
      line.update(contract_amount: nil)
      expect(line.first_sale_savings).to be_nil
    end

    it "returns nil when there's no tariff" do
      line.update(commercial_invoice_tariffs: [])
      expect(line.first_sale_savings).to be_nil
    end
  end

  describe "first_sale_difference" do
    let!(:line) { create(:commercial_invoice_line, contract_amount: 500, value: 200) }

    it "calculates first sale difference when contract amount isn't zero or nil" do
      expect(line.first_sale_difference).to eq 300
    end

    it "returns 0 when contract amount is 0" do
      line.update(contract_amount: 0)
      expect(line.first_sale_difference).to eq 0
    end

    it "returns nil when contract amount is nil" do
      line.update(contract_amount: nil)
      expect(line.first_sale_difference).to be_nil
    end
  end

  describe "value_for_tax" do
    let!(:line1) do
      create(:commercial_invoice_line,
              commercial_invoice_tariffs: [create(:commercial_invoice_tariff,
                                                   duty_amount: 1, entered_value: 2, sima_amount: 3, excise_amount: 4, value_for_duty_code: 1234)])
    end
    let!(:line2) do
      create(:commercial_invoice_line,
              commercial_invoice_tariffs: [create(:commercial_invoice_tariff,
                                                   duty_amount: 1, entered_value: 2, sima_amount: 3, excise_amount: 4, value_for_duty_code: nil)])
    end

    it "Returns the sum of all associated commercial_invoice_tariffs value of tax" do
      expect(line1.value_for_tax).to eq BigDecimal "10"
    end

    it "Does not return anything outside of Canada" do
      expect(line2.value_for_tax).to be_nil
    end
  end

  describe "first_sale_unit_price" do
    it "detrmines unit price from contract amount / quantity" do
      expect(create(:commercial_invoice_line, contract_amount: BigDecimal("100"), quantity: 3).first_sale_unit_price).to eq BigDecimal("33.33")
    end

    it "returns nil if contract amount is missing" do
      expect(create(:commercial_invoice_line, quantity: 3).first_sale_unit_price).to be_nil
    end

    it "returns 0 if contract amount is zero" do
      expect(create(:commercial_invoice_line, contract_amount: BigDecimal("0"), quantity: 3).first_sale_unit_price).to eq BigDecimal("0")
    end

    it "returns nil if quantity is nil" do
      expect(create(:commercial_invoice_line, contract_amount: BigDecimal("100")).first_sale_unit_price).to be_nil
    end

    it "returns nil if quantity is 0" do
      expect(create(:commercial_invoice_line, contract_amount: BigDecimal("100"), quantity: 0).first_sale_unit_price).to be_nil
    end
  end

  describe "gross_weight" do
    it "returns the first non-zero gross weight found in the tariff lines" do
      line = described_class.new
      line.commercial_invoice_tariffs.build gross_weight: BigDecimal("0")
      line.commercial_invoice_tariffs.build gross_weight: nil
      line.commercial_invoice_tariffs.build gross_weight: BigDecimal("4")
      line.commercial_invoice_tariffs.build gross_weight: BigDecimal("5")

      expect(line.gross_weight).to eq BigDecimal("4")
    end

    it "returns zero when no tariff weights are non-zero" do
      line = described_class.new
      line.commercial_invoice_tariffs.build gross_weight: BigDecimal("0")
      line.commercial_invoice_tariffs.build gross_weight: nil

      line_no_tariffs = described_class.new

      expect(line.gross_weight).to eq BigDecimal(0)
      expect(line_no_tariffs.gross_weight).to eq BigDecimal(0)
    end
  end
end
