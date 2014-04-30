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
end