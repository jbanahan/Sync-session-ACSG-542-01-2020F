describe ValidationRuleEntryInvoiceCooMatchesMid do
  let! (:company) { Factory(:company, system_code: 'ACOMPANY') }
  let! (:entry) { Factory(:entry) }

  it 'passes if invoice lines have mids which match the coo' do
    invoice = Factory(:commercial_invoice, entry: entry)
    invoice_line = Factory(:commercial_invoice_line, commercial_invoice: invoice, mid: 'AB123456', country_origin_code: 'AB')

    expect(subject.run_child_validation(invoice_line)).to be_nil
  end

  it 'fails if invoice lines have mids which do not match the coo' do
    invoice = Factory(:commercial_invoice, entry: entry)
    invoice_line = Factory(:commercial_invoice_line, commercial_invoice: invoice, po_number: '12345', mid: 'AB123456', country_origin_code: 'BA')

    expect(subject.run_child_validation(invoice_line)).to eql("MID 'AB123456' should have a Country of Origin of 'BA'.")
  end
end