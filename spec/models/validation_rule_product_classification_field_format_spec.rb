describe ValidationRuleProductClassificationFieldFormat do
  let!(:descr_cdef) { Factory(:custom_definition, module_type: 'Classification', data_type: 'string', label: 'Customs Description') }
  let!(:rule) { described_class.new(rule_attributes_json:{model_field_uid:descr_cdef.model_field_uid,regex:'good descr'}.to_json) }
  let!(:cl) do
    c = Factory(:classification)
    c.update_custom_value!(descr_cdef, 'good descr')
    c
  end
  let!(:p) { Factory(:product, unique_identifier: 'good UID', classifications: [cl]) }

  it 'should pass if all lines are valid' do
    expect(rule.run_validation(cl.product)).to be_nil
  end

  it 'should fail if any line is not valid' do
    cl.update_custom_value!(descr_cdef, 'bad descr')
    expect(rule.run_validation(cl.product)).to eq("All Classification - Customs Description values do not match 'good descr' format.")
  end

  context "fail_if_matches" do
    let(:rule) { described_class.new(rule_attributes_json:{model_field_uid:descr_cdef.model_field_uid,regex:'good descr', fail_if_matches: true}.to_json) }

    it "passes if all lines are valid" do
      cl.update_custom_value!(descr_cdef, 'foo')
      expect(rule.run_validation(cl.product)).to be_nil
    end

    it "fails if any line is not valid" do
      expect(rule.run_validation(cl.product)).to eq "At least one Classification - Customs Description value matches 'good descr' format."
    end
  end

  it 'should not allow blanks by default' do
    cl.update_custom_value!(descr_cdef, '')
    expect(rule.run_validation(cl.product)).to eq("All Classification - Customs Description values do not match 'good descr' format.")
  end

  it 'should allow blanks when allow_blank is true' do
    rule.rule_attributes_json = {allow_blank:true, model_field_uid:descr_cdef.model_field_uid,regex:'good descr'}.to_json
    cl.update_custom_value!(descr_cdef, '')
    expect(rule.run_validation(cl.product)).to be_nil
  end

  it 'should pass if classification that does not meet search criteria is invalid' do
    sima_cdef = Factory(:custom_definition, module_type: 'Classification', data_type: 'string', label: 'SIMA Code')
    rule.search_criterions.new(model_field_uid:sima_cdef.model_field_uid, operator:'eq', value:'good SIMA')
    bad_cl = Factory(:classification, product: p)
    bad_cl.update_custom_value!(descr_cdef, 'bad descr')
    bad_cl.update_custom_value!(sima_cdef, 'bad SIMA')
    cl.update_custom_value!(sima_cdef, 'good SIMA')
    p.reload
    expect(rule.run_validation(cl.product)).to be_nil
  end

  describe 'should_skip?' do

    it 'should skip on product validation level' do
      rule.search_criterions.build(model_field_uid:'prod_uid',operator:'eq',value:'bad UID')
      expect(rule.should_skip?(cl.product)).to be_truthy
    end

    it 'should skip on product classification level validation' do
      rule.search_criterions.build(model_field_uid:descr_cdef.model_field_uid,operator:'eq',value:'bad descr')
      expect(rule.should_skip?(cl.product)).to be_truthy
    end

    it 'should pass when matching all validations' do
      rule.search_criterions.build(model_field_uid:'prod_uid',operator:'eq',value:'good UID')
      rule.search_criterions.build(model_field_uid:descr_cdef.model_field_uid,operator:'eq',value:'good descr')
      expect(rule.should_skip?(cl.product)).to be_falsey
    end
  end
end
