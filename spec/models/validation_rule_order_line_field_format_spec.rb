require 'spec_helper'

describe ValidationRuleOrderLineFieldFormat do
  before :each do
    @rule = described_class.new(rule_attributes_json:{model_field_uid:'ordln_hts',regex:'ABC'}.to_json)
    @ol = Factory(:order_line, hts: 'ABC')
    @o = Factory(:order, order_lines: [@ol])
  end

  it 'should pass if all lines are valid' do
    expect(@rule.run_validation(@ol.order)).to be_nil
  end

  it 'should fail if any line is not valid' do
    @ol.update_attributes(hts: 'xyz')
    expect(@rule).to receive(:stop_validation)
    expect(@rule.run_validation(@ol.order)).to eq("All Order Line - HTS Code values do not match 'ABC' format.")
  end

  it 'does not stop validation if validate_all flag is used' do
    @ol.update_attributes(hts: 'xyz')
    @rule.rule_attributes_json = {model_field_uid:'ordln_hts',regex:'ABC', validate_all: true}.to_json
    expect(@rule).not_to receive(:stop_validation)
    expect(@rule.run_validation(@ol.order)).to eq("All Order Line - HTS Code values do not match 'ABC' format.")
  end

  context "fail_if_matches" do
    let(:rule) { described_class.new(rule_attributes_json:{model_field_uid:'ordln_hts',regex:'ABC', fail_if_matches: true}.to_json) }

    it "passes if all lines are valid" do
      @ol.update_attributes(hts: "foo")
      expect(rule.run_validation(@ol.order)).to be_nil
    end

    it "fails if any line is not valid" do
      expect(rule.run_validation(@ol.order)).to eq("At least one Order Line - HTS Code value matches 'ABC' format.")
    end
  end

  it 'should not allow blanks by default' do
    @ol.update_attributes(hts: '')
    expect(@rule.run_validation(@ol.order)).to eq("All Order Line - HTS Code values do not match 'ABC' format.")
  end

  it 'should allow blanks when allow_blank is true' do
    @rule.rule_attributes_json = {allow_blank:true, model_field_uid: 'ordln_hts',regex:'ABC'}.to_json
    @ol.update_attributes(hts: '')
    expect(@rule.run_validation(@ol.order)).to be_nil
  end

  it 'should pass if order line that does not meet search criteria is invalid' do
    @rule.search_criterions.new(model_field_uid: 'ordln_hts', operator:'eq', value:'ABC')
    @bad_ol = Factory(:order_line, hts: 'XYZ')
    @o.update_attributes(order_lines: [@ol, @bad_ol])
    expect(@rule.run_validation(@ol.order)).to be_nil
  end

  describe "should_skip?" do

    it "should skip on order validation level" do
      @ol.order.update_attributes(order_number:'1234321')
      @rule.search_criterions.build(model_field_uid:'ord_ord_num',operator:'eq',value:'99')
      expect(@rule.should_skip?(@ol.order)).to be_truthy
    end

    it "should skip on order line level validation" do
      @ol.update_attributes(hts:'XYZ')
      @rule.search_criterions.build(model_field_uid:'ordln_hts',operator:'eq',value:'99')
      expect(@rule.should_skip?(@ol.order)).to be_truthy
    end

    it "should pass when matching all validations" do
      @ol.order.update_attributes(order_number:'1234321')
      @ol.update_attributes(hts:'ABCDE')
      @ol.reload
      @rule.search_criterions.build(model_field_uid:'ord_ord_num',operator:'eq',value:'1234321')
      @rule.search_criterions.build(model_field_uid:'ordln_hts',operator:'eq',value:'ABCDE')
      expect(@rule.should_skip?(@ol.order)).to be_falsey
    end
  end
end