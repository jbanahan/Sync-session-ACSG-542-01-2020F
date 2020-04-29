describe OpenChain::CustomHandler::Pepsi::QuakerValidationRulePoNumberUnique do
  before :each do
    @rule = described_class.new
    @entry = Factory(:entry, entry_number: "5432154321", customer_number: 'QSD')
    @entry_2 = Factory(:entry, entry_number: "1234512345", customer_number: 'QSD')
    @ci_1 = Factory(:commercial_invoice, entry: @entry)
    @ci_2 = Factory(:commercial_invoice, entry: @entry_2)
    Factory(:commercial_invoice_line, commercial_invoice: @ci_1, po_number: "C123456")
  end

  it "passes if all invoice lines have unique po numbers" do
    Factory(:commercial_invoice_line, commercial_invoice: @ci_2, po_number: "C654321")
    expect(@rule.run_validation(@entry)).to be_nil
  end

  it "passes if there are duplicate invoices that aren't C+6-digits" do
    Factory(:commercial_invoice_line, commercial_invoice: @ci_1, po_number: "1111")
    Factory(:commercial_invoice_line, commercial_invoice: @ci_2, po_number: "1111")
    expect(@rule.run_validation(@entry)).to be_nil
  end

  it "passes if any po number of the form C+6-digits appears more than once on current entry" do
    Factory(:commercial_invoice_line, commercial_invoice: @ci_1, po_number: "C654321")
    expect(@rule.run_validation(@entry)).to be_nil
  end

  it "fails if any po number on the current entry of the form C+6-digits appears on another entry" do
    Factory(:commercial_invoice_line, commercial_invoice: @ci_2, po_number: "C123456")
    expect(@rule.run_validation(@entry)).to eq "The following po numbers appear on other entries:\nC123456 on entry 1234512345"
  end
end