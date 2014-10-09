require 'spec_helper'

describe ValidationRuleAnyEntryInvoiceLineHasFieldFormat do
  before :each do
    @rule = described_class.new(rule_attributes_json:{model_field_uid:'cil_part_number',regex:'ABC'}.to_json)
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
end