describe VfiInvoice do

  describe "can_view?" do
    before :each do
      @inv = FactoryBot(:vfi_invoice)
      @u = FactoryBot(:user)
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

  describe "search_secure" do
    let!(:linked_cust) { FactoryBot(:company, importer: true) }
    let(:cust) { FactoryBot(:company, importer: true, linked_companies: [linked_cust]) }
    let!(:master_user) { FactoryBot(:master_user) }
    let!(:customer_user) { FactoryBot(:user, company: cust) }
    let!(:other_customer_user) { FactoryBot(:user, company: FactoryBot(:company, importer: true)) }
    let!(:linked_invoice) { FactoryBot(:vfi_invoice, customer: linked_cust) }
    let!(:customer_invoice) { FactoryBot(:vfi_invoice, customer: cust) }
    let!(:unassociated_invoice) { FactoryBot(:vfi_invoice) }

    it "finds all for master" do
      expect(VfiInvoice.search_secure(master_user, VfiInvoice.where("1=1")).sort {|a, b| a.id<=>b.id}).to eq([linked_invoice, customer_invoice, unassociated_invoice].sort {|a, b| a.id<=>b.id})
    end
    it "finds customer's invoices" do
      expect(VfiInvoice.search_secure(customer_user, VfiInvoice.where("1=1")).sort {|a, b| a.id<=>b.id}).to eq([linked_invoice, customer_invoice].sort {|a, b| a.id<=>b.id})
    end
    it "doesn't find other customer's invoices" do
      expect(VfiInvoice.search_secure(other_customer_user, VfiInvoice.where("1=1"))).to be_empty
    end
  end

  describe "next_invoice_number" do
    it "yields a uid matching the id of the next record" do
      FactoryBot(:vfi_invoice)
      inv = VfiInvoice.next_invoice_number { |num| VfiInvoice.create!(invoice_number: num, customer_id: FactoryBot(:company).id) }
      expect(inv.invoice_number).to eq "VFI-#{inv.id}"
    end
  end

end
