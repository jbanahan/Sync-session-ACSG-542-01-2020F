describe ValidationRuleBrokerInvoiceLineFieldFormat do
  before do
    @rule = described_class.new(rule_attributes_json:{model_field_uid: 'bi_line_charge_amount', operator: 'gt', value: 5000}.to_json)
    @bil = FactoryBot(:broker_invoice_line, charge_description: 'Something', charge_amount: 5100)
    @bi = FactoryBot(:broker_invoice, customer_number: '123', broker_invoice_lines: [@bil])
    @e = FactoryBot(:entry, broker_invoices: [@bi])
  end

  it 'should pass if all lines are valid' do
    expect(@rule.run_validation(@bil.broker_invoice.entry)).to be_nil
  end

  it 'should fail if any line is not valid' do
    @bil.update_attribute(:charge_amount, 4900)
    expect(@rule.run_validation(@bil.broker_invoice.entry)).to eq("Broker Invoice # #{@bil.broker_invoice.invoice_number} / Charge Code #{@bil.charge_code} Broker Invoice Line - Amount value '#{@bil.charge_amount}' does not match '5000' format.")
  end

  it 'should pass if invoice that does not meet search criteria is invalid' do
    @rule.search_criterions.new(model_field_uid: 'bi_line_charge_code', operator:'eq', value:'123')
    @bad_bil = FactoryBot(:broker_invoice_line, charge_code: '321', charge_amount: 4900)
    @bi.update_attributes(broker_invoice_lines: [@bil, @bad_bil])
    expect(@rule.run_validation(@bil.broker_invoice.entry)).to be_nil
  end
end

