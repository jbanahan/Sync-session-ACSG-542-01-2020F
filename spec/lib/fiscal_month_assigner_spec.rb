describe OpenChain::FiscalMonthAssigner do
  let(:co) { Factory(:company, fiscal_reference: "ent_release_date") }
  let(:ent) { Factory(:entry, entry_number: "entry num", importer: co, release_date: DateTime.new(2016,3,31,12,0), 
                              arrival_date: Date.new(2016,04,15), fiscal_date: nil, fiscal_month: nil, fiscal_year: nil) }
  let!(:brok_inv) { Factory(:broker_invoice, entry: ent, invoice_number: "inv num", invoice_date: Date.new(2016,04,15), fiscal_date: nil, 
                                            fiscal_month: nil, fiscal_year: nil)}
  let!(:fm1) { Factory(:fiscal_month, company: co, year: 2016, month_number: 3, start_date: Date.new(2016,03,01), end_date: Date.new(2016,03,31)) }
  let!(:fm2) { Factory(:fiscal_month, company: co, year: 2016, month_number: 4, start_date: Date.new(2016,04,01), end_date: Date.new(2016,04,30)) }

  describe "assign" do
    it "assigns entry and invoice fiscal_date/month/year fields" do
      described_class.assign ent
      expect(ent.fiscal_date).to eq fm1.start_date
      expect(ent.fiscal_month).to eq fm1.month_number
      expect(ent.fiscal_year).to eq fm1.year
      expect(ent.broker_invoices.first.fiscal_date).to eq fm2.start_date
      expect(ent.broker_invoices.first.fiscal_month).to eq fm2.month_number
      expect(ent.broker_invoices.first.fiscal_year).to eq fm2.year
    end

    it "skips broker invoices marked for destruction" do
      # For whatever reason (feels like an ActiveRecord bug), if you 
      # call broker_invoices.first.mark_for_destruction the association
      # doesn't "stay" and the record is not marked for destruction.
      # ent.broker_invoices.first.mark_for_destruction
      # ent.broker_invoices.first.marked_for_destruction? # -> false WTF!!
      # ent.broker_invoices[0].mark_for_destruction 
      # ent.broker_invoices[0].marked_for_destruction? # -> true, correct!
      ent.broker_invoices[0].mark_for_destruction

      described_class.assign ent
      expect(ent.fiscal_date).to eq fm1.start_date
      expect(ent.fiscal_month).to eq fm1.month_number
      expect(ent.fiscal_year).to eq fm1.year

      expect(ent.broker_invoices.first.fiscal_date).to eq nil
      expect(ent.broker_invoices.first.fiscal_month).to eq nil
      expect(ent.broker_invoices.first.fiscal_year).to eq nil
    end

    it "does nothing if company doesn't have fiscal calendar enabled" do
      co.update_attributes!(fiscal_reference: "")
      described_class.assign ent
      expect(ent.fiscal_date).to eq nil
      expect(ent.fiscal_month).to eq nil
      expect(ent.fiscal_year).to eq nil
      expect(ent.broker_invoices.first.fiscal_date).to eq nil
      expect(ent.broker_invoices.first.fiscal_month).to eq nil
      expect(ent.broker_invoices.first.fiscal_year).to eq nil
    end

    it "assigns blank fiscal attributes if entry field corresponding to company's fiscal reference is blank" do
      ent.update_attributes!(release_date: nil, fiscal_date: Date.today, fiscal_month: 1, fiscal_year: 2016)
      described_class.assign ent
      expect(ent.fiscal_date).to be_nil
      expect(ent.fiscal_month).to be_nil
      expect(ent.fiscal_year).to be_nil
    end

    it "assigns blank fiscal attributes if broker invoice date is blank" do
      brok_inv.update_attributes!(invoice_date: nil, fiscal_date: Date.today, fiscal_month: 1, fiscal_year: 2016)
      described_class.assign ent
      expect(ent.broker_invoices.first.fiscal_date).to be_nil
      expect(ent.broker_invoices.first.fiscal_month).to be_nil
      expect(ent.broker_invoices.first.fiscal_year).to be_nil
    end

    it "raises exception if company's fiscal calendar is enabled but entry's date doesn't have a matching fiscal month" do
      ent.update_attributes!(release_date: DateTime.new(2016, 5, 15, 12, 00))
      expect{described_class.assign ent}.to raise_error "No fiscal month found for Entry #entry num with Release Date 2016-05-15."
    end

    it "raises exception if company's fiscal calendar is enabled but broker invoice's invoice_date doesn't have a matching fiscal month" do
      brok_inv.update_attributes!(invoice_date: Date.new(2016,5,15))
      expect{described_class.assign ent}.to raise_error "No fiscal month found for Broker Invoice #inv num with Invoice Date 2016-05-15."
    end

    it "raises exception if more than one fiscal month is found for an entry" do
      Factory(:fiscal_month, company: co, year: 2016, month_number: 5, start_date: Date.new(2016,3,2), end_date: Date.new(2016,4,20))
      expect{described_class.assign ent}.to raise_error "More than one fiscal month found for Entry #entry num with Release Date 2016-03-31."
    end

    it "raises exception if more than one fiscal month is found for a broker invoice" do
      Factory(:fiscal_month, company: co, year: 2016, month_number: 5, start_date: Date.new(2016,4,2), end_date: Date.new(2016,4,20))
      expect{described_class.assign ent}.to raise_error "More than one fiscal month found for Broker Invoice #inv num with Invoice Date 2016-04-15."
    end
  end
end