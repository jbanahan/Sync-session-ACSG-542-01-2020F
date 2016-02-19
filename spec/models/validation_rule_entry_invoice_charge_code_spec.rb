require 'spec_helper'

describe ValidationRuleEntryInvoiceChargeCode do
  before :each do
    @rule = ValidationRuleEntryInvoiceChargeCode.new(rule_attributes_json: {charge_codes: ['123', '456', '789']}.to_json)
    @entry = Factory(:entry)
    @broker_invoice = Factory(:broker_invoice, entry: @entry)
    @inv_line_1 = Factory(:broker_invoice_line, broker_invoice: @broker_invoice, charge_code: 123, charge_amount: 5)
    @inv_line_2 = Factory(:broker_invoice_line, broker_invoice: @broker_invoice, charge_code: 123, charge_amount: 10)
    @inv_line_3 = Factory(:broker_invoice_line, broker_invoice: @broker_invoice, charge_code: 456, charge_amount: 15)

  end

  it "passes if invoice lines with white-listed charge codes have a non-zero sum" do
    expect(@rule.run_validation(@entry)).to be_nil
  end

  it "passes if invoice lines not on white list have a zero sum" do
    Factory(:broker_invoice_line, broker_invoice: @broker_invoice, charge_code: 604, charge_amount: 5)
    Factory(:broker_invoice_line, broker_invoice: @broker_invoice, charge_code: 604, charge_amount: -5)
    expect(@rule.run_validation(@entry)).to be_nil
  end
  
  it "fails if invoice lines with charge codes not on white list have a non-zero sum" do
    Factory(:broker_invoice_line, broker_invoice: @broker_invoice, charge_code: 604, charge_amount: 5)
    Factory(:broker_invoice_line, broker_invoice: @broker_invoice, charge_code: 604, charge_amount: 10)
    expect(@rule.run_validation(@entry)).to eq "The following invalid charge codes were found: 604."
  end


end