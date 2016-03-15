require 'spec_helper'

describe ValidationRuleEntryInvoiceValueMatchesDaPercent do

  before :each do
    @rule = ValidationRuleEntryInvoiceValueMatchesDaPercent.new(rule_attributes_json: {adjustment_rate: 9.0}.to_json)
    @invoice = Factory(:commercial_invoice, invoice_number: "123B", invoice_value_foreign: 100)
    @invoice_line = Factory(:commercial_invoice_line, commercial_invoice: @invoice, adjustments_amount: 4.5)
    Factory(:commercial_invoice_line, commercial_invoice: @invoice, adjustments_amount: 4.5)
  end

  it "passes if the sum of the invoice lines' DA amount is the target percentage of the invoice's value" do
    expect(@rule.run_child_validation @invoice).to be_nil
  end

  it "passes if the sum of the invoice lines' DA amount is within a thousandth of the target percentage of the invoice's value" do
    @invoice_line.adjustments_amount = 4.509
    @invoice_line.save!
    expect(@rule.run_child_validation @invoice).to be_nil
  end

  it "fails if the sum of the invoice line's DA amount isn't the target percentage of the invoice's value" do
    Factory(:commercial_invoice_line, commercial_invoice: @invoice, adjustments_amount: 0.4)
    expect(@rule.run_child_validation @invoice).to eq "Invoice 123B has a DA amount that is 9.40% of the total, expected 9.00%."
  end
end