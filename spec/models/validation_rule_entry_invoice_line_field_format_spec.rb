describe ValidationRuleEntryInvoiceLineFieldFormat do
  before :each do
    @rule = described_class.new(rule_attributes_json:{model_field_uid:'cil_part_number', regex:'ABC'}.to_json)
    @ci_line = FactoryBot(:commercial_invoice_line, line_number:1, part_number:'ABC123', commercial_invoice: FactoryBot(:commercial_invoice, invoice_number: "INV"))
    @ci_line2 = FactoryBot(:commercial_invoice_line, line_number:2, part_number:'123ABC', commercial_invoice:@ci_line.commercial_invoice)
  end
  it "should pass if all lines are valid" do
    expect(@rule.run_validation(@ci_line.entry)).to be_nil
  end
  it "should fail if any line is not valid" do
    @ci_line2.update_attributes(part_number:'123')
    expect(@rule).to receive(:stop_validation)
    expect(@rule.run_validation(@ci_line.entry)).to eq "Invoice # INV / Line # 2 #{ModelField.find_by_uid(:cil_part_number).label} value '123' does not match 'ABC' format."
  end
  it "stops at first invalid line by default" do
    @ci_line.update_attributes(part_number:'987')
    @ci_line2.update_attributes(part_number:'123')
    expect(@rule.run_validation(@ci_line.entry)).to eq "Invoice # INV / Line # 1 #{ModelField.find_by_uid(:cil_part_number).label} value '987' does not match 'ABC' format."
  end
  it "should not allow blanks by default" do
    @ci_line2.update_attributes(part_number:'')
    expect(@rule.run_validation(@ci_line.entry)).to eq "Invoice # INV / Line # 2 #{ModelField.find_by_uid(:cil_part_number).label} value '' does not match 'ABC' format."
  end
  it "should allow blanks when allow_blank is true" do
    @rule.rule_attributes_json = {allow_blank:true, model_field_uid:'cil_part_number', regex:'ABC'}.to_json
    @ci_line2.update_attributes(part_number:'')
    expect(@rule.run_validation(@ci_line.entry)).to be_nil
  end
  it "should pass if line that does not meet search criteria is invalid" do
    @rule.search_criterions.new(model_field_uid:'ci_invoice_number', operator:'eq', value:'123')
    @ci_line.commercial_invoice.update_attributes(invoice_number:'123')
    bad_ci_line = FactoryBot(:commercial_invoice_line, part_number:'789', commercial_invoice:FactoryBot(:commercial_invoice, invoice_number:'456', entry:@ci_line.entry))
    expect(@rule.run_validation(@ci_line.entry)).to be_nil
  end

  it "should evaluate all lines when instructed" do
    @rule.update_attributes! name: "Name", description: "Description",  rule_attributes_json: {model_field_uid:'cil_part_number', regex:'YYZ', validate_all: true}.to_json
    expect(@rule.run_validation(@ci_line.entry)).to eq "Invoice # INV / Line # 1 Invoice Line - Part Number value 'ABC123' does not match 'YYZ' format.\nInvoice # INV / Line # 2 Invoice Line - Part Number value '123ABC' does not match 'YYZ' format."
  end

  context "fail_if_matches" do
    let(:rule) { described_class.new(rule_attributes_json:{model_field_uid:'cil_part_number', regex:'ABC', fail_if_matches: true}.to_json) }

    it "passes if all lines are valid" do
      @ci_line.update_attributes(part_number: 'foo')
      @ci_line2.update_attributes(part_number: 'bar')
      expect(rule.run_validation(@ci_line.entry)).to be_nil
    end

    it "fails if any line is not valid" do
      @ci_line.update_attributes(part_number: 'foo')
      expect(rule.run_validation(@ci_line.entry)).to eq "Invoice # INV / Line # 2 #{ModelField.find_by_uid(:cil_part_number).label} value should not match 'ABC' format."
    end
  end

  describe "should_skip?" do
    it "should skip on entry level validation" do
      @ci_line.entry.update_attributes(entry_number:'31612345678')
      @rule.search_criterions.build(model_field_uid:'ent_entry_num', operator:'sw', value:'99')
      expect(@rule.should_skip?(@ci_line.entry)).to be_truthy
    end
    it "should skip on commercial invoice level validation" do
      @ci_line.commercial_invoice.update_attributes(invoice_number:'ABC')
      @rule.search_criterions.build(model_field_uid:'ci_invoice_number', operator:'sw', value:'99')
      expect(@rule.should_skip?(@ci_line.entry)).to be_truthy
    end
    it "should skip on commercial invoice line level validation" do
      @ci_line.update_attributes(part_number:'ABC')
      @rule.search_criterions.build(model_field_uid:'cil_part_number', operator:'sw', value:'99')
      expect(@rule.should_skip?(@ci_line.entry)).to be_truthy
    end
    it "should pass when matching all validations" do
      @ci_line.entry.update_attributes(entry_number:'31612345678')
      @ci_line.commercial_invoice.update_attributes(invoice_number:'ABC')
      @ci_line.update_attributes(part_number:'ABC')
      @ci_line.reload
      @rule.search_criterions.build(model_field_uid:'ent_entry_num', operator:'sw', value:'31')
      @rule.search_criterions.build(model_field_uid:'ci_invoice_number', operator:'sw', value:'AB')
      @rule.search_criterions.build(model_field_uid:'cil_part_number', operator:'sw', value:'AB')
      expect(@rule.should_skip?(@ci_line.entry)).to be_falsey
    end
  end

end

