describe ValidationRuleEntryDoesNotSharePos do
  before :each do
    @rule = ValidationRuleEntryDoesNotSharePos.new
    @entry = Factory(:entry, importer_id: 555)
    @invoice = Factory(:commercial_invoice, entry: @entry)
    @ci_line = Factory(:commercial_invoice_line, commercial_invoice: @invoice, po_number: 'DO NOT REPEAT', line_number: 1)
  end

  it "passes if PO number is not shared over multiple entries" do
    expect(@rule.run_validation(@entry)).to be_nil
  end

  it "passes if PO number is shared between entries that have differing importers" do
    entry_2 = Factory(:entry, importer_id: 666)
    invoice_2 = Factory(:commercial_invoice, entry: entry_2)
    ci_line_2 = Factory(:commercial_invoice_line, commercial_invoice: invoice_2, po_number: 'DO NOT REPEAT', line_number: 1)

    expect(@rule.run_validation(@entry)).to be_nil
  end

  it "passes if PO number is shared on multiple lines within the same entry" do
    ci_line_2 = Factory(:commercial_invoice_line, commercial_invoice: @invoice, po_number: 'DO NOT REPEAT', line_number: 2)

    expect(@rule.run_validation(@entry)).to be_nil
  end

  it "passes if PO number is blank and blank PO value exists on multiple entries" do
    @ci_line.po_number = ''
    @ci_line.save!

    entry_2 = Factory(:entry, importer_id: 555)
    invoice_2 = Factory(:commercial_invoice, entry: entry_2)
    ci_line_2 = Factory(:commercial_invoice_line, commercial_invoice: invoice_2, po_number: '', line_number: 1)

    expect(@rule.run_validation(@entry)).to be_nil
  end

  it "fails if PO number is shared between entries with the same importer" do
    entry_2 = Factory(:entry, importer_id: 555, entry_number:'123ABC')
    invoice_2 = Factory(:commercial_invoice, entry: entry_2, invoice_number:'ABC123')
    ci_line_2 = Factory(:commercial_invoice_line, commercial_invoice: invoice_2, po_number: 'DO NOT REPEAT', line_number: 5)
    invoice_3 = Factory(:commercial_invoice, entry: entry_2, invoice_number:'DEF456')
    ci_line_3 = Factory(:commercial_invoice_line, commercial_invoice: invoice_3, po_number: 'DO NOT REPEAT', line_number: 3)

    expect(@rule.run_validation(@entry)).to eq "Purchase Order DO NOT REPEAT already exists on Entry 123ABC for Invoice ABC123, and line number 5. \nPurchase Order DO NOT REPEAT already exists on Entry 123ABC for Invoice DEF456, and line number 3."
  end

end
