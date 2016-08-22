require 'spec_helper'

describe ValidationRuleOrderVendorFieldFormat do
  it "should pass when field matches" do
    c = Factory(:company,vendor:true,name:'MyCompany')
    o = Factory(:order,vendor:c)
    json = {model_field_uid: :cmp_name, regex: "Company"}.to_json
    vr = described_class.create!(rule_attributes_json:json)

    expect(vr.run_validation(o)).to be_nil
  end
  it "should fail when field does not match" do
    c = Factory(:company,vendor:true,name:'MyCompany')
    o = Factory(:order,vendor:c)
    json = {model_field_uid: :cmp_name, regex: "BAD"}.to_json
    vr = described_class.create!(rule_attributes_json:json)

    expect(vr.run_validation(o)).not_to be_blank
  end
end