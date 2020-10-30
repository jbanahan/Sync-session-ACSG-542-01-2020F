describe CustomReportEntryInvoiceBreakdown do

  context "static methods" do
    let(:klass) { described_class }
    let(:master_user) { Factory(:master_user) }
    let(:importer_user) { Factory(:importer_user) }

    it "has all column fields available from BROKER_INVOICE that the user can see" do
      fields = klass.column_fields_available master_user
      to_find = CoreModule::BROKER_INVOICE.model_fields.values.collect {|mf| mf if mf.can_view?(master_user)}.compact!
      expect(fields).to eq(to_find)
    end

    it "does not show column fields that user doesn't have permission to see" do
      fields = klass.column_fields_available importer_user
      expect(fields.index {|mf| mf.uid == :bi_duty_due_date}).to be_nil
    end

    it "allows all column fields as criterion fields" do
      expect(klass.criterion_fields_available(importer_user)).to eq(klass.column_fields_available(importer_user))
    end

    it "allows users who can view broker invoices to view" do
      allow(master_user).to receive(:view_broker_invoices?).and_return(true)
      expect(klass.can_view?(master_user)).to be_truthy
    end

    it "does not allow users who cannot view broker invoices to view" do
      allow(master_user).to receive(:view_broker_invoices?).and_return(false)
      expect(klass.can_view?(master_user)).to be_falsey
    end
  end

  it "produces report" do
    master_user = Factory(:master_user)
    allow(master_user).to receive(:view_broker_invoices?).and_return(true)
    invoice_line = Factory(:broker_invoice_line, charge_description: "CD1", charge_amount: 100.12)
    invoice_line.broker_invoice.entry.update(entry_number: "31612345678", broker_reference: "1234567")
    Factory(:broker_invoice_line, broker_invoice: invoice_line.broker_invoice, charge_description: "CD2", charge_amount: 55)
    broker_invoice_2 = Factory(:broker_invoice, entry: invoice_line.broker_invoice.entry)
    Factory(:broker_invoice_line, broker_invoice: broker_invoice_2, charge_description: "CD3", charge_amount: 50.02)
    Factory(:broker_invoice_line, broker_invoice: broker_invoice_2, charge_description: "CD4", charge_amount: 26.40)

    rpt = described_class.create!
    rpt.search_columns.create!(model_field_uid: :bi_entry_num, rank: 1)
    rpt.search_columns.create!(model_field_uid: :bi_brok_ref, rank: 1)
    sheet = rpt.to_arrays master_user

    expect(sheet[0][0]).to eq ModelField.by_uid(:bi_entry_num).label
    expect(sheet[0][2]).to eq "CD1"
    expect(sheet[1][0]).to eq "31612345678"
    expect(sheet[1][2]).to eq 100.12
    expect(sheet[2][0]).to eq "31612345678"
  end

end
