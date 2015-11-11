require 'spec_helper'

describe ValidationRuleOrderVendorFieldFormat do
  it "should pass when field matches" do
    c = Factory(:company,vendor:true,name:'MyCompany')
    o = Factory(:order,vendor:c)
    json = {model_field_uid: :cmp_name, regex: "Company"}.to_json
    vr = described_class.create!(rule_attributes_json:json)

    vr.run_validation(o).should be_nil
  end
  it "should fail when field does not match" do
    c = Factory(:company,vendor:true,name:'MyCompany')
    o = Factory(:order,vendor:c)
    json = {model_field_uid: :cmp_name, regex: "BAD"}.to_json
    vr = described_class.create!(rule_attributes_json:json)

    vr.run_validation(o).should_not be_blank
  end
end