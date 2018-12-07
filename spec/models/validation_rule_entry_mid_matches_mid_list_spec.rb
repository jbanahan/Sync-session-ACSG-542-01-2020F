require 'spec_helper'

describe ValidationRuleEntryMidMatchesMidList do

  let! (:company) { Factory(:company, system_code: 'ACOMPANY') }
  let! (:entry) { Factory(:entry, mfids: "1234567890\n ") }

  subject { ValidationRuleEntryMidMatchesMidList.new(rule_attributes_json: {importer: 'ACOMPANY'}.to_json) }

  it 'raises an error if given no company system code' do
    subject.update_attribute(:rule_attributes_json, nil)
    expect{subject.run_validation(entry)}.to raise_error("No importer specified")
  end
  
  it 'raises an error if no company exists with given system code' do
    company.update_attribute(:system_code, 'BCOMPANY')
    expect{subject.run_validation(entry)}.to raise_error("Invalid importer system code")
  end

  it 'passes if the specified importer has no mid_xrefs' do
    expect(subject.run_validation(entry)).to be_nil
  end

  it 'passes if all mfids on an entry are in the data cross reference' do
    xref = DataCrossReference.create!(company_id: company.id, cross_reference_type: DataCrossReference::ENTRY_MID_VALIDATIONS, key: '1234567890')
    expect(subject.run_validation(entry)).to be_nil
  end

  it 'passes even if an mfid contains leading/trailing spaces' do
    xref = DataCrossReference.create!(company_id: company.id, cross_reference_type: DataCrossReference::ENTRY_MID_VALIDATIONS, key: ' 1234567890 ')
    expect(subject.run_validation(entry)).to be_nil
  end

  it 'fails if any mfid on an entry is not in the data cross reference' do
    xref = DataCrossReference.create!(company_id: company.id, cross_reference_type: DataCrossReference::ENTRY_MID_VALIDATIONS, key: '1234567890')
    entry.update_attribute(:mfids, "0987654321\n ")
    entry.reload
    expect(subject.run_validation(entry)).to_not be_nil
  end

  it 'provides a failure message for an mfid that is not in the data cross reference' do
    xref = DataCrossReference.create!(company_id: company.id, cross_reference_type: DataCrossReference::ENTRY_MID_VALIDATIONS, key: '1234567890')
    entry.update_attribute(:mfids, "0987654321\n ")
    entry.reload
    expect(subject.run_validation(entry)).to eql("Manufacturer ID 0987654321 not found in cross reference")
  end
end