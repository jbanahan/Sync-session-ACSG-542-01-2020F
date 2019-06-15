describe ValidationRuleEntryInvoiceFieldFormat do
  before :each do
    @rule = described_class.new(rule_attributes_json:{model_field_uid:'ci_issue_codes',regex:'ABC'}.to_json)
    @ci = Factory(:commercial_invoice, issue_codes: 'ABC', invoice_number:'DEFGH')
    @e = Factory(:entry, commercial_invoices: [@ci])
  end

  it 'should pass if all lines are valid' do
    expect(@rule.run_validation(@ci.entry)).to be_nil
  end

  it 'should fail if any line is not valid' do
    @ci.update_attributes(issue_codes: 'xyz')
    expect(@rule.run_validation(@ci.entry)).to eq("Invoice DEFGH Invoice - Issue Tracking Codes value 'xyz' does not match 'ABC' format.")
  end

  it 'should not allow blanks by default' do
    @ci.update_attributes(issue_codes: '')
    expect(@rule.run_validation(@ci.entry)).to eq("Invoice DEFGH Invoice - Issue Tracking Codes value '' does not match 'ABC' format.")
  end

  it 'should allow blanks when allow_blank is true' do
    @rule.rule_attributes_json = {allow_blank:true, model_field_uid: 'ci_issue_codes',regex:'ABC'}.to_json
    @ci.update_attributes(issue_codes: '')
    expect(@rule.run_validation(@ci.entry)).to be_nil
  end

  it 'should pass if invoice that does not meet search criteria is invalid' do
    @rule.search_criterions.new(model_field_uid: 'ci_issue_codes', operator:'eq', value:'ABC')
    @bad_ci = Factory(:commercial_invoice, issue_codes: 'XYZ')
    @e.update_attributes(commercial_invoices: [@ci, @bad_ci])
    expect(@rule.run_validation(@ci.entry)).to be_nil
  end

  it "evaluates all invoices if instructed" do
    expect(@rule).not_to receive(:stop_validation)
    @rule.rule_attributes_json = {model_field_uid:'ci_issue_codes',regex:'ABC', validate_all: "true"}.to_json
    @ci.update_attributes(issue_codes: 'xyz')
    expect(@rule.run_validation(@ci.entry)).to eq("Invoice DEFGH Invoice - Issue Tracking Codes value 'xyz' does not match 'ABC' format.")
  end

  context "fail_if_matches" do
    let(:rule) { described_class.new(rule_attributes_json:{model_field_uid:'ci_issue_codes',regex:'ABC', fail_if_matches: true}.to_json) }
    
    it 'passes if all lines are valid' do
      @ci.update_attributes(issue_codes: 'foo')
      expect(rule.run_validation(@ci.entry)).to be_nil
    end

    it 'fails if any line is not valid' do
      expect(rule.run_validation(@ci.entry)).to eq("Invoice DEFGH Invoice - Issue Tracking Codes value should not match 'ABC' format.")
    end
  end

  describe "should_skip?" do

    it "should skip on entry validation level" do
      @ci.entry.update_attributes(entry_number:'1234321')
      @rule.search_criterions.build(model_field_uid:'ent_entry_num',operator:'eq',value:'99')
      expect(@rule.should_skip?(@ci.entry)).to be_truthy
    end

    it "should skip on commercial invoice level validation" do
      @ci.update_attributes(issue_codes:'XYZ')
      @rule.search_criterions.build(model_field_uid:'ci_issue_codes',operator:'eq',value:'99')
      expect(@rule.should_skip?(@ci.entry)).to be_truthy
    end

    it "should pass when matching all validations" do
      @ci.entry.update_attributes(entry_number:'1234321')
      @ci.update_attributes(issue_codes:'ABCDE')
      @ci.reload
      @rule.search_criterions.build(model_field_uid:'ent_entry_num',operator:'eq',value:'1234321')
      @rule.search_criterions.build(model_field_uid:'ci_issue_codes',operator:'eq',value:'ABCDE')
      expect(@rule.should_skip?(@ci.entry)).to be_falsey
    end
  end
end
