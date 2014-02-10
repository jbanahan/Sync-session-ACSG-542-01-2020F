require 'spec_helper'

describe ValidationRuleEntryInvoiceLineFieldFormat do
  before :each do
    @rule = described_class.new(rule_attributes_json:{model_field_uid:'cil_part_number',regex:'ABC'}.to_json)
    @ci_line = Factory(:commercial_invoice_line, part_number:'ABC123')
    @ci_line2 = Factory(:commercial_invoice_line, part_number:'123ABC',commercial_invoice:@ci_line.commercial_invoice)
  end
  it "should pass if all lines are valid" do
    expect(@rule.run_validation(@ci_line.entry)).to be_nil
  end
  it "should fail if any line is not valid" do
    @ci_line2.update_attributes(part_number:'123')
    expect(@rule.run_validation(@ci_line.entry)).to eq "All #{ModelField.find_by_uid(:cil_part_number).label} values do not match 'ABC' format."
  end
  it "should not allow blanks by default" do
    @ci_line2.update_attributes(part_number:'')
    expect(@rule.run_validation(@ci_line.entry)).to eq "All #{ModelField.find_by_uid(:cil_part_number).label} values do not match 'ABC' format."
  end
  it "should allow blanks when allow_blank is true" do
    @rule.rule_attributes_json = {allow_blank:true, model_field_uid:'cil_part_number',regex:'ABC'}.to_json
    @ci_line2.update_attributes(part_number:'')
    expect(@rule.run_validation(@ci_line.entry)).to be_nil
  end
end

