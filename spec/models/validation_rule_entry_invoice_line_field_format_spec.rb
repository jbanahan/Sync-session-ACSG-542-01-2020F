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
  it "should pass if line that does not meet search criteria is invalid" do
    @rule.search_criterions.new(model_field_uid:'ci_invoice_number',operator:'eq',value:'123')
    @ci_line.commercial_invoice.update_attributes(invoice_number:'123')
    bad_ci_line = Factory(:commercial_invoice_line,part_number:'789',commercial_invoice:Factory(:commercial_invoice,invoice_number:'456',entry:@ci_line.entry))
    expect(@rule.run_validation(@ci_line.entry)).to be_nil
  end

  describe :should_skip? do
    it "should skip on entry level validation" do
      @ci_line.entry.update_attributes(entry_number:'31612345678')
      @rule.search_criterions.build(model_field_uid:'ent_entry_num',operator:'sw',value:'99')
      expect(@rule.should_skip?(@ci_line.entry)).to be_true
    end
    it "should skip on commercial invoice level validation" do
      @ci_line.commercial_invoice.update_attributes(invoice_number:'ABC')
      @rule.search_criterions.build(model_field_uid:'ci_invoice_number',operator:'sw',value:'99')
      expect(@rule.should_skip?(@ci_line.entry)).to be_true
    end
    it "should skip on commercial invoice line level validation" do
      @ci_line.update_attributes(part_number:'ABC')
      @rule.search_criterions.build(model_field_uid:'cil_part_number',operator:'sw',value:'99')
      expect(@rule.should_skip?(@ci_line.entry)).to be_true
    end
    it "should pass when matching all validations" do
      @ci_line.entry.update_attributes(entry_number:'31612345678')
      @ci_line.commercial_invoice.update_attributes(invoice_number:'ABC')
      @ci_line.update_attributes(part_number:'ABC')
      @ci_line.reload
      @rule.search_criterions.build(model_field_uid:'ent_entry_num',operator:'sw',value:'31')
      @rule.search_criterions.build(model_field_uid:'ci_invoice_number',operator:'sw',value:'AB')
      @rule.search_criterions.build(model_field_uid:'cil_part_number',operator:'sw',value:'AB')
      expect(@rule.should_skip?(@ci_line.entry)).to be_false
    end
  end

end

