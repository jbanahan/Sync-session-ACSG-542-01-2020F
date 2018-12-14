describe InvoiceLine do 

  subject { 
    InvoiceLine.new air_sea_discount: BigDecimal("1"), early_pay_discount: BigDecimal("2"), trade_discount: BigDecimal("3"), middleman_charge: BigDecimal("4")
  }

  describe "calculate_total_discounts" do

    it "sums all discount attributes from line" do
      expect(subject.calculate_total_discounts).to eq 6
    end

    it "handles nil value in one discount" do
      subject.early_pay_discount = nil
      expect(subject.calculate_total_discounts).to eq 4
    end

    it "handles all nil values" do
      subject.early_pay_discount = nil
      subject.air_sea_discount = nil
      subject.trade_discount = nil
      expect(subject.calculate_total_discounts).to eq 0
    end
  end

  describe "calculate_total_charges" do
    it "sums all charges from line" do
      expect(subject.calculate_total_charges).to eq 4
    end

    it "handles nil" do
      subject.middleman_charge = nil
      expect(subject.calculate_total_charges).to eq 0
    end
  end
end