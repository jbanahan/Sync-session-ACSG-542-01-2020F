require 'spec_helper'

describe ValidationRuleAnyEntryInvoiceLineHasFieldFormat do
  before :each do
    @rule = described_class.new( name: "Name", description: "Description", rule_attributes_json:{model_field_uid:'cil_part_number',regex:'ABC'}.to_json)
    @ci_line = Factory(:commercial_invoice_line, part_number:'ABC123')
    @ci_line2 = Factory(:commercial_invoice_line, part_number:'123',commercial_invoice:@ci_line.commercial_invoice)
  end

  it "passes if a single line matches regex" do 
    expect(@rule.run_validation(@ci_line.entry)).to be_nil
  end

  it "fails if no line matches regex" do
    @ci_line.update_attributes! part_number: "XYZ"
    expect(@rule.run_validation(@ci_line.entry)).to eq "At least one #{ModelField.find_by_uid(:cil_part_number).label} value must match 'ABC' format."
  end

  context "fail_if_matches" do
    let(:rule) { described_class.new(rule_attributes_json:{model_field_uid:'cil_part_number',regex:'ABC',fail_if_matches: true}.to_json) }

    it "passes if a single line doesn't match regex" do
      expect(rule.run_validation(@ci_line.entry)).to be_nil
    end

    it "fails if every line matches regex" do
      @ci_line2.update_attributes(part_number: "ABC")
      expect(rule.run_validation(@ci_line2.entry)).to eq "At least one #{ModelField.find_by_uid(:cil_part_number).label} value must NOT match 'ABC' format."
    end
  end

  it "raies an error if multiple model fields are configured" do
    @rule.update_attributes! rule_attributes_json: {'cil_part_number' => {regex: 'ABC'}, 'cil_po_number' => {regex: 'ABC'}}.to_json

    expect {@rule.run_validation(@ci_line.entry)}.to raise_error "Using multiple model fields is not supported with this business rule."
  end
end
