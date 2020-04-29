describe ValidationRuleInvoiceLineMidFirstSale do
  let! (:company) { Factory(:company, system_code: 'ACOMPANY') }
  let! (:entry) { Factory(:entry) }

  subject { ValidationRuleInvoiceLineMidFirstSale.new(rule_attributes_json: {importer: 'ACOMPANY'}.to_json) }

  it 'raises an error if given no company system code' do
    subject.update_attribute(:rule_attributes_json, nil)
    expect { subject.run_validation(entry)}.to raise_error("No importer specified")
  end

  it 'raises an error if no company exists with given system code' do
    company.update_attribute(:system_code, 'BCOMPANY')
    expect { subject.run_validation(entry) }.to raise_error("Invalid importer system code")
  end

  it 'passes if there are no xrefs in the system' do
    expect(DataCrossReference.hash_for_type(DataCrossReference::ENTRY_MID_VALIDATIONS, company_id: company.id)).to be_blank
    expect(subject.run_validation(entry)).to be_nil
  end

  it 'passes if the entry has no commercial_invoices' do
    expect(entry.commercial_invoices).to be_blank
    expect(subject.run_validation(entry)).to be_nil
  end

  it 'passes if all invoice lines that have a mid are marked first_sale (handling nil as first_sale)' do
    invoice = Factory(:commercial_invoice, entry: entry)
    invoice_line_1 = Factory(:commercial_invoice_line, commercial_invoice: invoice, mid: '123456789', first_sale: nil)
    xref = DataCrossReference.create!(company_id: company.id, cross_reference_type: DataCrossReference::ENTRY_MID_VALIDATIONS, key: 123456789)

    expect(subject.run_validation(entry)).to be_empty
  end

  it 'passes if all invoice lines that have a mid are marked first_sale' do
    invoice = Factory(:commercial_invoice, entry: entry)
    invoice_line_1 = Factory(:commercial_invoice_line, commercial_invoice: invoice, mid: '123456789', first_sale: true)
    xref = DataCrossReference.create!(company_id: company.id, cross_reference_type: DataCrossReference::ENTRY_MID_VALIDATIONS, key: 123456789)
    invoice_line_1 = Factory(:commercial_invoice_line, commercial_invoice: invoice, first_sale: true)

    expect(subject.run_validation(entry)).to be_empty
  end

  it 'fails if any invoice lines have a mid not marked first_sale' do
    invoice = Factory(:commercial_invoice, entry: entry)
    invoice_line_1 = Factory(:commercial_invoice_line, commercial_invoice: invoice, po_number: "12345", mid: '123456789', first_sale: false)
    xref = DataCrossReference.create!(company_id: company.id, cross_reference_type: DataCrossReference::ENTRY_MID_VALIDATIONS, key: 123456789)

    expect(subject.run_validation(entry)).to eql(["PO 12345 and MID # 123456789 should have first sale data."])
  end

  it 'provides a proper error message if multiple invoice_lines fail.' do
    invoice = Factory(:commercial_invoice, entry: entry)
    invoice_line_1 = Factory(:commercial_invoice_line, commercial_invoice: invoice, po_number: "12345", mid: '123456789', first_sale: false)
    invoice_line_1 = Factory(:commercial_invoice_line, commercial_invoice: invoice, po_number: "12345", mid: '123456789', first_sale: false)
    xref = DataCrossReference.create!(company_id: company.id, cross_reference_type: DataCrossReference::ENTRY_MID_VALIDATIONS, key: 123456789)

    expect(subject.run_validation(entry)).to eql(["PO 12345 and MID # 123456789 should have first sale data.", "PO 12345 and MID # 123456789 should have first sale data."])
  end

end