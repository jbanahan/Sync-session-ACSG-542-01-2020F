require 'spec_helper'

describe ValidationRuleOrderLineProductFieldFormat do
  it "should fail when product doesn't match" do
    p = Factory(:product,unique_identifier:'px')
    ol = Factory(:order_line,product:p)
    json = {model_field_uid: :prod_uid, regex: "ABC"}.to_json
    vr = described_class.create!(rule_attributes_json:json)

    expect(vr.run_validation(ol.order)).not_to be_blank
  end
  it "should pass when product does match" do
    p = Factory(:product,unique_identifier:'ABC')
    ol = Factory(:order_line,product:p)
    json = {model_field_uid: :prod_uid, regex: "ABC"}.to_json
    vr = described_class.create!(rule_attributes_json:json)

    expect(vr.run_validation(ol.order)).to be_nil
  end
end