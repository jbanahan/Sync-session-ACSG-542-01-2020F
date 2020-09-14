describe ValidationRuleAssistApplied do
  subject { described_class.new(rule_attributes_json: {importer: 'ACOMPANY'}.to_json) }

  let!(:company) { Factory(:company, system_code: 'ACOMPANY') }
  let!(:entry) { Factory(:entry) }
  let!(:ci) { Factory(:commercial_invoice, entry: entry) }

  it 'handles not having an importer specified' do
    entry.update(importer: company)

    cil = Factory(:commercial_invoice_line, commercial_invoice: ci)
    subject.update(rule_attributes_json: nil)
    expect { subject.run_child_validation(cil) }.not_to raise_error("No importer specified")
  end

  it 'raises an error if no company exists with given system code' do
    cil = Factory(:commercial_invoice_line, commercial_invoice: ci)
    company.update(system_code: 'BCOMPANY')
    expect { subject.run_child_validation(cil) }.to raise_error("Invalid importer system code")
  end

  it 'passes if the specified importer has no part_xrefs' do
    cil = Factory(:commercial_invoice_line, commercial_invoice: ci)
    expect(subject.run_child_validation(cil)).to be_nil
  end

  it 'fails if line has no adjusted value and the part_xref is active' do
    cil = Factory(:commercial_invoice_line, commercial_invoice: ci, part_number: '1234')
    DataCrossReference.create!(company: company, cross_reference_type: 'part_xref', key: '1234', value: 'true')
    expect(subject.run_child_validation(cil)).to eq("Invoice line for Part number 1234 has no adjusted value")
  end

  it 'passes if line has an adjusted value and the part_xref is active' do
    cil = Factory(:commercial_invoice_line, commercial_invoice: ci, part_number: '1234', adjustments_amount: 100)
    DataCrossReference.create!(company: company, cross_reference_type: 'part_xref', key: '1234', value: 'true')
    expect(subject.run_child_validation(cil)).to be_nil
  end

  it 'passes if line has no adjusted value and the part_xref is inactive' do
    cil = Factory(:commercial_invoice_line, commercial_invoice: ci, part_number: '1234')
    DataCrossReference.create!(company: company, cross_reference_type: 'part_xref', key: '1234', value: 'false')
    expect(subject.run_child_validation(cil)).to be_nil
  end

  it 'passes if line has no adjusted value and there is no part_xref' do
    cil = Factory(:commercial_invoice_line, commercial_invoice: ci, part_number: '1234')
    expect(subject.run_child_validation(cil)).to be_nil
  end
end