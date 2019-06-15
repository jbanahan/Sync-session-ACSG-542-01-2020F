describe VfiInvoiceLine do
  let(:inv_line) { Factory(:vfi_invoice_line, unit_price: 15.30, quantity: 2) }

  describe "get_charge_amount" do
    it "multiplies the quantity on the invoice by its unit price" do
      expect(inv_line.get_charge_amount).to eq 30.60
    end
  end

  describe "set_charge_amount" do
    it "gets assigns charge amount" do
      inv_line.set_charge_amount
      expect(inv_line.charge_amount).to eq 30.60
    end
  end
end
