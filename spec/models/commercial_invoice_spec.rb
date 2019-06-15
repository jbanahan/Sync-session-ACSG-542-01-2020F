describe CommercialInvoice do
  describe "search_secure" do
    it "should find all if from master company" do
      ci = Factory(:commercial_invoice)
      u = Factory(:master_user)
      expect(described_class.search_secure(u,described_class).to_a).to eql [ci]
    end
    it "should find for linked companies by importer" do
      dont_find = Factory(:commercial_invoice)
      find = Factory(:commercial_invoice,importer:Factory(:company))
      u = Factory(:user)
      u.company.linked_companies << find.importer
      expect(described_class.search_secure(u,described_class).to_a).to eql [find]
    end
    it "should find if company is importer" do
      dont_find = Factory(:commercial_invoice)
      find = Factory(:commercial_invoice,importer:Factory(:company))
      u = Factory(:user,company:find.importer)
      expect(described_class.search_secure(u,described_class).to_a).to eql [find]
    end
    it "should find for linked companies by vendor" do
      dont_find = Factory(:commercial_invoice)
      find = Factory(:commercial_invoice,vendor:Factory(:company))
      u = Factory(:user)
      u.company.linked_companies << find.vendor
      expect(described_class.search_secure(u,described_class).to_a).to eql [find]
    end
    it "should find if company is vendor" do
      dont_find = Factory(:commercial_invoice)
      find = Factory(:commercial_invoice,vendor:Factory(:company))
      u = Factory(:user,company:find.vendor)
      expect(described_class.search_secure(u,described_class).to_a).to eql [find]
    end
  end
  describe "can_edit?" do
    before(:each) do
      MasterSetup.get.update_attributes(:entry_enabled=>true)
      @ci = CommercialInvoice.new
    end
    it "should allow edit if user from master company and can edit invoices" do
      u = Factory(:master_user,company: Factory(:company, master: true, broker: true), entry_edit:true)
      expect(@ci.can_edit?(u)).to be_truthy
    end
    it "should allow edit if user from same company as importer and can edit invoices" do
      u = Factory(:master_user,company: Factory(:company, importer: true, broker: true), entry_edit:true)
      @ci.importer = u.company
      expect(@ci.can_edit?(u)).to be_truthy
    end
    it "should allow edit if importer linked to user's company and can edit" do
      c = Factory(:company)
      u = Factory(:master_user,company: Factory(:company, importer: true, broker: true), entry_edit:true)
      u.company.linked_companies << c
      @ci.importer = c
      expect(@ci.can_edit?(u)).to be_truthy
    end
    it "should allow edit if user from vendor company and can edit" do
      u = Factory(:master_user,company: Factory(:company, vendor: true, broker: true), entry_edit:true)
      @ci.vendor = u.company
      expect(@ci.can_edit?(u)).to be_truthy
    end
    it "should allow edit if user linked to vendor company and can edit" do
      c = Factory(:company)
      u = Factory(:master_user,company: Factory(:company, vendor: true, broker: true), entry_edit:true)
      u.company.linked_companies << c
      @ci.vendor = c
      expect(@ci.can_edit?(u)).to be_truthy
    end
    it "should not allow random user to edit" do
      imp = Factory(:company)
      vend = Factory(:company)
      @ci.vendor = vend
      @ci.importer = imp
      expect(@ci.can_edit?(Factory(:user,commercial_invoice_edit:true))).to be_falsey
    end
    it "should not allow user who can't edit to edit" do
      u = Factory(:master_user,company: Factory(:company, importer: true, broker: true), entry_edit:false)
      expect(@ci.can_edit?(u)).to be_falsey
    end
  end
  describe "can_view?" do
    before :each do
      MasterSetup.get.update_attributes(:entry_enabled=>true)
    end
    it "should allow view if user is from master and can view invoices" do
      u = Factory(:master_user,company: Factory(:company, master: true), entry_view:true)
      expect(CommercialInvoice.new.can_view?(u)).to be_truthy
    end
    it "should allow view if user is from importer and can view invoices" do
      c = Factory(:company,:importer=>true)
      u = Factory(:master_user,company: c, entry_view:true)
      expect(CommercialInvoice.new(:importer=>c).can_view?(u)).to be_truthy
    end
  end
  
  describe "destroys_snapshots?" do
    it "destroys snapshots for standalone invoice" do
      expect(subject.destroys_snapshots?).to eq true
    end

    it "does not destroy snapshots for invoices linked to entries" do
      subject.entry_id = 1
      expect(subject.destroys_snapshots?).to eq false
    end
  end
  
  describe "value_for_tax" do
    let(:ci1) {Factory(:commercial_invoice, commercial_invoice_lines:
      [Factory(:commercial_invoice_line,
        commercial_invoice_tariffs: [Factory(:commercial_invoice_tariff, duty_amount: 1, entered_value: 2, value_for_duty_code: 1234)]),
      Factory(:commercial_invoice_line,
        commercial_invoice_tariffs: [Factory(:commercial_invoice_tariff, duty_amount: 1, entered_value: 2, value_for_duty_code: 1234)])
      ])}
    let(:ci2) {Factory(:commercial_invoice, commercial_invoice_lines:
      [Factory(:commercial_invoice_line,
        commercial_invoice_tariffs: [Factory(:commercial_invoice_tariff, duty_amount: 1, entered_value: 2, value_for_duty_code: nil)]),
      Factory(:commercial_invoice_line,
        commercial_invoice_tariffs: [Factory(:commercial_invoice_tariff, duty_amount: 1, entered_value: 2, value_for_duty_code: 1234)])
      ])}

    it "Returns the sum of all associated invoice_line invoice_tariffs value of tax" do
      expect(ci1.value_for_tax).to eq BigDecimal.new "6"
    end

    it "Does not include values of tariffs outside of Canada" do
      expect(ci2.value_for_tax).to eq BigDecimal.new "3"
    end
  end
end
