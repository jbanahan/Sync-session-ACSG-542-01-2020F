require 'spec_helper'

describe OpenChain::CustomHandler::Pepsi::QuakerValidationRuleInvoiceNumberUnique do
  before :each do
    @rule = described_class.new
    @entry = Factory(:entry, entry_number: "5432154321", customer_number: 'QSD')
    @entry_2 = Factory(:entry, entry_number: "1234512345", customer_number: 'QSD')
    Factory(:commercial_invoice, entry: @entry, invoice_number: "C123456")
    Factory(:commercial_invoice, entry: @entry, invoice_number: "C654321")
    Factory(:commercial_invoice, entry: @entry, invoice_number: "1111")
  end
  
  it "passes if all invoices have unique numbers" do
    expect(@rule.run_validation(@entry)).to be_nil
  end

  it "passes if there are duplicate invoices that aren't C+6-digits" do
    Factory(:commercial_invoice, entry: @entry, invoice_number: "1111")
    Factory(:commercial_invoice, entry: @entry_2, invoice_number: "1111")
    expect(@rule.run_validation(@entry)).to be_nil
  end

  it "passes if any invoice number of the form C+6-digits appears more than once on current entry" do
    Factory(:commercial_invoice, entry: @entry, invoice_number: "C654321")
    expect(@rule.run_validation(@entry)).to be_nil
  end

  it "fails if any invoice number on the current entry of the form C+6-digits appears on another entry" do
    Factory(:commercial_invoice, entry: @entry_2, invoice_number: "C654321")
    expect(@rule.run_validation(@entry)).to eq "The following invoice numbers appear on other entries:\nC654321 on entry 1234512345"
  end
end