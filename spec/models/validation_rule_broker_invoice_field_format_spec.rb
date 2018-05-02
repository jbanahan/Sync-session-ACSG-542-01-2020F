require 'spec_helper'

describe ValidationRuleBrokerInvoiceFieldFormat do
  before do
    @rule = described_class.new(rule_attributes_json:{model_field_uid: 'bi_invoice_total', operator: 'gt', value: 5000}.to_json)
    @bi = Factory(:broker_invoice, invoice_total: 5100, customer_number: '123')
    @e = Factory(:entry, broker_invoices: [@bi])
  end

  it 'should pass if all lines are valid' do
    expect(@rule.run_validation(@bi.entry)).to be_nil
  end

  it 'should fail if any line is not valid' do
    @bi.update_attribute(:invoice_total, 4900)
    expect(@rule.run_validation(@bi.entry)).to eq("Broker Invoice # #{@bi.invoice_number} Total value '4900.0' does not match '5000' format.")
  end

  it 'should not allow blanks by default' do
    @bi.update_attributes(invoice_total: '')
    expect(@rule.run_validation(@bi.entry)).to eq("Broker Invoice # #{@bi.invoice_number} Total value '' does not match '5000' format.")
  end

  it 'should allow blanks when allow_blank is true' do
    @rule.rule_attributes_json = {allow_blank:true, model_field_uid: 'bi_invoice_total',operator: 'gt', value:5000}.to_json
    @bi.update_attributes(invoice_total: '')
    expect(@rule.run_validation(@bi.entry)).to be_nil
  end

  it 'should pass if invoice that does not meet search criteria is invalid' do
    @rule.search_criterions.new(model_field_uid: 'bi_customer_number', operator:'eq', value:'123')
    @bad_bi = Factory(:broker_invoice, customer_number: '321', invoice_total: 4900)
    @e.update_attributes(broker_invoices: [@bi, @bad_bi])
    expect(@rule.run_validation(@bi.entry)).to be_nil
  end
end