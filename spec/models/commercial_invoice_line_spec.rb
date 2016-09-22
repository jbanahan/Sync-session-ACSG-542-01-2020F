require 'spec_helper'

describe CommercialInvoiceLine do
  describe "duty_plus_fees_amount" do
    it "sums all duty and fees for a line" do
      line = CommercialInvoiceLine.new prorated_mpf: BigDecimal.new("1"), hmf: BigDecimal.new("2"), cotton_fee: BigDecimal.new("3")
      line.commercial_invoice_tariffs.build duty_amount: BigDecimal.new("4")
      line.commercial_invoice_tariffs.build duty_amount: BigDecimal.new("5")

      expect(line.duty_plus_fees_amount).to eq BigDecimal.new "15"
    end

    it "handles nil values in all fields" do
      line = CommercialInvoiceLine.new
      line.commercial_invoice_tariffs.build

      expect(line.duty_plus_fees_amount).to eq BigDecimal.new "0"
    end
  end

  describe "total_duty" do
    it "sum duty for line" do
      line = CommercialInvoiceLine.new 
      line.commercial_invoice_tariffs.build duty_amount: BigDecimal.new("4")
      line.commercial_invoice_tariffs.build duty_amount: BigDecimal.new("5")

      expect(line.total_duty).to eq BigDecimal.new "9"
    end
  end

  describe "total_fees" do
    it "sums fees for line" do
      expect(CommercialInvoiceLine.new(prorated_mpf: BigDecimal.new("1"), hmf: BigDecimal.new("2"), cotton_fee: BigDecimal.new("3")).total_fees).to eq BigDecimal.new("6")
    end
  end

  describe "total_entered_value" do
    it "sums entered value for all tariff lines" do
      line = CommercialInvoiceLine.new 
      line.commercial_invoice_tariffs.build entered_value: BigDecimal.new("4")
      line.commercial_invoice_tariffs.build entered_value: BigDecimal.new("5")

      expect(line.total_entered_value).to eq BigDecimal("9")
    end
  end

  describe "duty_plus_fees_add_cvd_amounts" do
    it "calculates duty plus all fees" do
      line = CommercialInvoiceLine.new prorated_mpf: BigDecimal.new("1"), hmf: BigDecimal.new("2"), cotton_fee: BigDecimal.new("3"), cvd_duty_amount: BigDecimal("10"), add_duty_amount: BigDecimal("20")
      line.commercial_invoice_tariffs.build duty_amount: BigDecimal.new("4")
      line.commercial_invoice_tariffs.build duty_amount: BigDecimal.new("5")

      expect(line.duty_plus_fees_add_cvd_amounts).to eq BigDecimal("45")
    end
  end

  describe "first_sale_savings" do
    let!(:line) { Factory(:commercial_invoice_line, contract_amount: 500, value: 200, 
                     commercial_invoice_tariffs: [Factory(:commercial_invoice_tariff, duty_amount: 30, entered_value: 10)]) }
    
    it "calculates first sale savings when contract amount isn't zero or nil" do
      expect(line.first_sale_savings).to eq 900
      # amount - value * duty_amount / entered_value
    end

    it "returns 0 when contract amount is 0" do
      line.update_attributes(contract_amount: 0)
      expect(line.first_sale_savings).to eq 0
    end

    it "returns 0 when contract amount is nil" do
      line.update_attributes(contract_amount: nil)
      expect(line.first_sale_savings).to eq 0
    end

    it "returns 0 when there's no tariff" do
      line.update_attributes(commercial_invoice_tariffs: [])
      expect(line.first_sale_savings).to eq 0
    end
  end

  describe "first_sale_difference" do
    let!(:line) { Factory(:commercial_invoice_line, contract_amount: 500, value: 200) }

    it "calculates first sale difference when contract amount isn't zero or nil" do
      expect(line.first_sale_difference).to eq 300
    end

    it "returns 0 when contract amount is 0" do
      line.update_attributes(contract_amount: 0)
      expect(line.first_sale_difference).to eq 0
    end

    it "returns 0 when contract amount is nil" do
      line.update_attributes(contract_amount: nil)
      expect(line.first_sale_difference).to eq 0
    end
  end
end