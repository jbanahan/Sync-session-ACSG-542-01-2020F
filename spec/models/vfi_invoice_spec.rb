require 'spec_helper'

describe VfiInvoice do

  describe :can_view? do
    before :each do
      @inv = Factory(:vfi_invoice)
      @u = Factory(:user)
    end

    it "returns true if user has permission" do
      @u.stub(:view_vfi_invoices?).and_return true
      expect(@inv.can_view? @u).to eq true
    end

    it "returns falsy otherwise" do
      expect(@inv.can_view? @u).to be_false
    end
  end

  describe "next_invoice_number" do
    it "yields a uid matching the id of the next record" do
      Factory(:vfi_invoice)
      inv = VfiInvoice.next_invoice_number { |num| VfiInvoice.create!(invoice_number: num, customer: Factory(:company)) }
      expect(inv.invoice_number).to eq "VFI-#{inv.id}"
    end
  end

end