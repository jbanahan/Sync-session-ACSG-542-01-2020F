require 'spec_helper'

describe ValidationRuleFieldFormat do
  it "should validate a field by regex" do
    json = {model_field_uid: :ord_ord_num, regex:'X.*Y'}.to_json
    vr = ValidationRuleFieldFormat.create!(rule_attributes_json:json)
    expect(vr.run_validation(Order.new(order_number:'XabcY'))).to be_nil
    expect(vr.run_validation(Order.new(order_number:'Xabc'))).to eq "#{ModelField.find_by_uid(:ord_ord_num).label} must match 'X.*Y' format, but was 'Xabc'"
  end
  context :blank do
    it "should not allow blank" do
      json = {model_field_uid: :ord_ord_num, regex:'X.*Y'}.to_json
      vr = ValidationRuleFieldFormat.create!(rule_attributes_json:json)
      expect(vr.run_validation(Order.new)).to eq "#{ModelField.find_by_uid(:ord_ord_num).label} must match 'X.*Y' format, but was ''"
    end
    it "should allow blank if allow_blank is true" do
      json = {model_field_uid: :ord_ord_num, regex:'X.*Y', allow_blank: true}.to_json
      vr = ValidationRuleFieldFormat.create!(rule_attributes_json:json)
      expect(vr.run_validation(Order.new)).to be_nil
    end
  end
end
