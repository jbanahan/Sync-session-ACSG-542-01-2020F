require 'spec_helper'

describe ValidationRuleEntryMidMatchesMidList do
  before do
    @company = Factory(:company, system_code: 'ACOMPANY')
    @rule = ValidationRuleEntryMidMatchesMidList.new(rule_attributes_json: {importer: 'ACOMPANY'}.to_json)
    @entry = Factory(:entry, mfids: "1234567890\n ")
  end

  subject {described_class.new}

  it 'raises an error if given no company system code' do
    @rule.update_attribute(:rule_attributes_json, nil)
    expect{@rule.run_validation(@entry)}.to raise_error("No importer specified")
  end
  
  it 'raises an error if no company exists with given system code' do
    @company.update_attribute(:system_code, 'BCOMPANY')
    expect{@rule.run_validation(@entry)}.to raise_error("Invalid importer system code")
  end

  it 'passes if the specified importer has no mid_xrefs' do
    expect(@rule.run_validation(@entry)).to be_nil
  end

  it 'passes if all mfids on an entry are in the data cross reference' do
    xref = DataCrossReference.create!(company_id: @company.id, cross_reference_type: 'mid_xref', key: '1234567890')
    expect(@rule.run_validation(@entry)).to be_nil
  end

  it 'passes even if an mfid contains leading/trailing spaces' do
    xref = DataCrossReference.create!(company_id: @company.id, cross_reference_type: 'mid_xref', key: ' 1234567890 ')
    expect(@rule.run_validation(@entry)).to be_nil
  end

  it 'fails if any mfid on an entry is not in the data cross reference' do
    xref = DataCrossReference.create!(company_id: @company.id, cross_reference_type: 'mid_xref', key: '1234567890')
    @entry.update_attribute(:mfids, "0987654321\n ")
    @entry.reload
    expect(@rule.run_validation(@entry)).to_not be_nil
  end

  it 'provides a failure message for an mfid that is not in the data cross reference' do
    xref = DataCrossReference.create!(company_id: @company.id, cross_reference_type: 'mid_xref', key: '1234567890')
    @entry.update_attribute(:mfids, "0987654321\n ")
    @entry.reload
    expect(@rule.run_validation(@entry)).to eql("Manufacturer ID 0987654321 not found in cross reference")
  end
end