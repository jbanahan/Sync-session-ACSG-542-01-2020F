describe CommercialInvoiceTariff do
  describe "canadian?" do
    it "returns true if the value_for_duty_vode field is present" do
      cit = Factory(:commercial_invoice_tariff, value_for_duty_code: 1234)
      expect(cit.canadian?).to be true
    end

    it "returns false otherwise" do
      cit = Factory(:commercial_invoice_tariff)
      expect(cit.canadian?).to be false
    end
  end

  describe "value_for_tax" do
    it "returns the sum of entered_value + duty_amount + sima_amount + excise_amount" do
      cit = Factory(:commercial_invoice_tariff,
        entered_value: 1, duty_amount: 1, sima_amount: 1, excise_amount: 1, value_for_duty_code: 1234)
      expect(cit.value_for_tax).to eq BigDecimal("4")
    end

    it "returns nil when the value_for_duty_code is nil. ie non-canadian" do
      cit = Factory(:commercial_invoice_tariff,
        entered_value: 1, duty_amount: 1, sima_amount: 1, excise_amount: 1, value_for_duty_code: nil)
      expect(cit.value_for_tax).to be_nil
    end
  end

end
