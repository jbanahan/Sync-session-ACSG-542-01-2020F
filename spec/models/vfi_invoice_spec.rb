require 'spec_helper'

describe VfiInvoice do

  describe "can_view?" do
    before :each do
      @inv = Factory(:vfi_invoice)
      @u = Factory(:user)
    end

    context "user has permission to view invoices" do
      before(:each) { allow(@u).to receive(:view_vfi_invoices?).and_return true }
      
      it "returns true if user belongs to master company" do
        co = @u.company
        co.update_attributes(master: true)
        expect(@inv.can_view? @u).to eq true
      end

      it "returns true if user's company matches the invoice's customer" do
        @u.company = @inv.customer; @u.save!
        expect(@inv.can_view? @u).to eq true
      end

      it "returns true if one of user's linked companies matches the invoice's customer" do
        @u.company.linked_companies << @inv.customer; @u.company.save!
        expect(@inv.can_view? @u).to eq true
      end

      it "returns falsy otherwise" do
        expect(@inv.can_view? @u).to be_falsey
      end
    end

    it "returns falsy if user doesn't have permission to view invoices" do
      co = @u.company
      co.update_attributes(master: true)
      expect(@inv.can_view? @u).to be_falsey
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