describe BrokerInvoice do
  describe "hst_amount" do
    it "should calculate HST based on existing charge codes" do
      with_hst_code_1 = Factory(:charge_code,:apply_hst=>true)
      with_hst_code_2 = Factory(:charge_code,:apply_hst=>true)
      without_hst = Factory(:charge_code,:apply_hst=>false)

      bi = BrokerInvoice.new
      bi.broker_invoice_lines.build(:charge_code=>with_hst_code_1.code,:charge_description=>with_hst_code_1.description,:charge_amount=>10,:hst_percent=>0.05)
      bi.broker_invoice_lines.build(:charge_code=>with_hst_code_2.code,:charge_description=>with_hst_code_2.description,:charge_amount=>20,:hst_percent=>0.10)
      bi.broker_invoice_lines.build(:charge_code=>without_hst.code,:charge_description=>with_hst_code_1.description,:charge_amount=>10)

      expect(bi.hst_amount).to eq(2.5)
    end
  end
  context 'currency' do
    it "should default currency to USD" do
      bi = BrokerInvoice.create!
      expect(bi.currency).to eq("USD")
    end
    it "should leave existing currency alone" do
      expect(BrokerInvoice.create!(:currency=>"CAD").currency).to eq("CAD")
    end
  end
  context 'security' do
    before :each do
      MasterSetup.get.update!(:broker_invoice_enabled=>true)
      @importer = Factory(:company,:importer=>true)
      @importer_user = Factory(:user,:company_id=>@importer.id,:broker_invoice_view=>true)
      @entry = Factory(:entry,:importer_id=>@importer.id)
      @inv = Factory(:broker_invoice,:entry_id=>@entry.id)
    end
    context 'search secure' do
      before :each do
        entry_2 = Factory(:entry,:importer_id=>Factory(:company,:importer=>true).id)
        inv_2 = Factory(:broker_invoice,:entry_id=>entry_2.id)
      end
      it 'should restrict non master by entry importer id' do
        found = BrokerInvoice.search_secure(@importer_user,BrokerInvoice)
        expect(found.size).to eq(1)
        expect(found.first).to eq(@inv)
      end
      it 'should allow all for master' do
        u = Factory(:user,:broker_invoice_view=>true)
        u.company.update!(:master=>true)
        found = BrokerInvoice.search_secure(u,BrokerInvoice)
        expect(found.size).to eq(2)
      end
      it 'should allow for linked company' do
        child = Factory(:company,:importer=>true)
        i3 = Factory(:broker_invoice,:entry=>Factory(:entry,:importer_id=>child.id))
        @importer.linked_companies << child
        expect(BrokerInvoice.search_secure(@importer_user,BrokerInvoice).all).to eq([@inv,i3])
      end
    end
    it 'should be visible for importer' do
      expect(@inv.can_view?(@importer_user)).to be_truthy 
    end
    it 'should not be visible for another importer' do
      u = Factory(:user,:company_id=>Factory(:company,:importer=>true).id,:broker_invoice_view=>true)
      expect(@inv.can_view?(u)).to be_falsey
    end
    it 'should be visible for parent importer' do
      parent = Factory(:company,:importer=>true)
      parent.linked_companies << @importer
      u = Factory(:user,:company_id=>parent.id,:broker_invoice_view=>true)
      expect(@inv.can_view?(u)).to be_truthy
    end
    it 'should not be visible without permission' do
      u = Factory(:user,:broker_invoice_view=>false)
      u.company.update!(:master=>true)
      expect(@inv.can_view?(u)).to be_falsey
    end
    it 'should not be visible without company permission' do
      u = Factory(:user,:broker_invoice_view=>true)
      expect(@inv.can_view?(u)).to be_falsey
    end
    it 'should be visible with permission' do
      u = Factory(:user,:broker_invoice_view=>true)
      u.company.update!(:master=>true)
      expect(@inv.can_view?(u)).to be_truthy
    end
    it "should be editable with permission and view permission" do
      allow(@inv).to receive(:can_view?).and_return(true)
      u = User.new
      allow(u).to receive(:edit_broker_invoices?).and_return true
      expect(@inv.can_edit?(u)).to be_truthy
    end
    it "should not be editable without view permission" do
      allow(@inv).to receive(:can_view?).and_return(false)
      u = User.new
      allow(u).to receive(:edit_broker_invoices?).and_return true
      expect(@inv.can_edit?(u)).to be_falsey
    end
    it "should not be editable without edit permission" do
      allow(@inv).to receive(:can_view?).and_return(true)
      u = User.new
      allow(u).to receive(:edit_broker_invoices?).and_return false
      expect(@inv.can_edit?(u)).to be_falsey
    end
    it "should not be editable if locked" do
      allow(@inv).to receive(:can_view?).and_return(true)
      u = User.new
      allow(u).to receive(:edit_broker_invoices?).and_return true
      @inv.locked = true
      expect(@inv.can_edit?(u)).to be_falsey
    end
  end

  describe "total_billed_duty_amount" do
    let (:broker_invoice) {
      inv = BrokerInvoice.new
      inv.broker_invoice_lines << BrokerInvoiceLine.new(charge_amount: BigDecimal("10"), charge_code: "0001")
      inv.broker_invoice_lines << BrokerInvoiceLine.new(charge_amount: BigDecimal("-10"), charge_code: "0001")
      inv.broker_invoice_lines << BrokerInvoiceLine.new(charge_amount: BigDecimal("10"), charge_code: "0002")
      inv.broker_invoice_lines << BrokerInvoiceLine.new(charge_amount: BigDecimal("50"), charge_code: "0001")

      inv
    }

    it "sums charge amounts for duty lines" do
      expect(broker_invoice.total_billed_duty_amount).to eq 50
    end

    it "returns zero if invoice is marked for destruction" do
      broker_invoice.mark_for_destruction

      expect(broker_invoice.total_billed_duty_amount).to eq 0
    end

    it "skips lines marked for destruction" do
      broker_invoice.broker_invoice_lines[0].mark_for_destruction
      expect(broker_invoice.total_billed_duty_amount).to eq 40
    end
  end

  describe "has_charge_code?" do
    it "returns true if charge code contained in lines" do
      inv = BrokerInvoice.new
      inv.broker_invoice_lines << BrokerInvoiceLine.new(charge_amount: BigDecimal("10"), charge_code: "0001")
      inv.broker_invoice_lines << BrokerInvoiceLine.new(charge_amount: BigDecimal("10"), charge_code: "0002")

      expect(inv.has_charge_code? "0001").to be true
      expect(inv.has_charge_code? "0002").to be true
      expect(inv.has_charge_code? "0003").to be false
      expect(inv.has_charge_code? nil).to be false
    end
  end
end
