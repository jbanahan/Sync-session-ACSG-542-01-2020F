describe ValidationRuleOrderVendorFieldFormat do
  it "should pass when field matches" do
    c = Factory(:company,vendor:true,name:'MyCompany')
    o = Factory(:order,vendor:c)
    json = {model_field_uid: :cmp_name, regex: "Company"}.to_json
    vr = described_class.create!(name: "Name", description: "Description", rule_attributes_json:json)

    expect(vr.run_validation(o)).to be_nil
  end
  it "should fail when field does not match" do
    c = Factory(:company,vendor:true,name:'MyCompany')
    o = Factory(:order,vendor:c)
    json = {model_field_uid: :cmp_name, regex: "BAD"}.to_json
    vr = described_class.create!(name: "Name", description: "Description", rule_attributes_json:json)

    expect(vr.run_validation(o)).not_to be_blank
  end

  context "fail_if_matches" do
    let(:vr) { described_class.create!(name: "Name", description: "Description", rule_attributes_json:{model_field_uid: :cmp_name, regex: "Company", fail_if_matches: true}.to_json) }

    it "passes when field doesn't match" do
      c = Factory(:company,vendor:true,name:'foo')
      o = Factory(:order,vendor:c)
      expect(vr.run_validation(o)).to be_nil
    end

    it "fails when field does match" do
      c = Factory(:company,vendor:true,name:'MyCompany')
      o = Factory(:order,vendor:c)
      expect(vr.run_validation(o)).to eq "At least one Name value matches 'Company' format for Vendor MyCompany."
    end
  end
end
