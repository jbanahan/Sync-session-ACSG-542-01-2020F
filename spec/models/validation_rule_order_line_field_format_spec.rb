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
    expect(@rule.run_validation(@ol.order)).to eq("All Order Line - HTS Code values do not match 'ABC' format.")
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

  describe :should_skip? do

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