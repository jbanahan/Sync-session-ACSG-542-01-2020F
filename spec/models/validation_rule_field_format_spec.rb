require 'spec_helper'

describe ValidationRuleFieldFormat do
  it "handles checking equality on two fields" do
    commercial_invoice_line = Factory(:commercial_invoice_line, value: 35, contract_amount: 6)
    json = {model_field_uid: :cil_value, operator: "eq", value: :cil_contract_amount}.to_json
    vr = ValidationRuleFieldFormat.create!( name: "Name", description: "Description", rule_attributes_json:json)
    expect(vr.run_validation(commercial_invoice_line)).to eq "#{ModelField.find_by_uid(:cil_value).label} must match '6.0' format but was '35.0'."
    commercial_invoice_line.update_attribute(:contract_amount, 35)
    json = {model_field_uid: :cil_value, operator: "eq", value: :cil_contract_amount}.to_json
    vr = ValidationRuleFieldFormat.create!(name: "Name", description: "Description", rule_attributes_json:json)
    expect(vr.run_validation(commercial_invoice_line)).to be_nil
  end

  it "handles checking if two fields are greater than one another" do
    commercial_invoice_line = Factory(:commercial_invoice_line, value: 6, contract_amount: 35)
    json = {model_field_uid: :cil_value, operator: "gt", value: :cil_contract_amount}.to_json
    vr = ValidationRuleFieldFormat.create!( name: "Name", description: "Description", rule_attributes_json:json)
    expect(vr.run_validation(commercial_invoice_line)).to eq "#{ModelField.find_by_uid(:cil_value).label} must match '35.0' format but was '6.0'."
    commercial_invoice_line.update_attribute(:contract_amount, 1)
    json = {model_field_uid: :cil_value, operator: "gt", value: :cil_contract_amount}.to_json
    vr = ValidationRuleFieldFormat.create!(name: "Name", description: "Description", rule_attributes_json:json)
    expect(vr.run_validation(commercial_invoice_line)).to be_nil
  end

  it "handles checking if two fields are less than one another" do
    commercial_invoice_line = Factory(:commercial_invoice_line, value: 40, contract_amount: 35)
    json = {model_field_uid: :cil_value, operator: "lt", value: :cil_contract_amount}.to_json
    vr = ValidationRuleFieldFormat.create!( name: "Name", description: "Description", rule_attributes_json:json)
    expect(vr.run_validation(commercial_invoice_line)).to eq "#{ModelField.find_by_uid(:cil_value).label} must match '35.0' format but was '40.0'."
    commercial_invoice_line.update_attribute(:contract_amount, 45)
    json = {model_field_uid: :cil_value, operator: "lt", value: :cil_contract_amount}.to_json
    vr = ValidationRuleFieldFormat.create!(name: "Name", description: "Description", rule_attributes_json:json)
    expect(vr.run_validation(commercial_invoice_line)).to be_nil
  end

  it "handles checking inequality on two fields" do
    commercial_invoice_line = Factory(:commercial_invoice_line, value: 35, contract_amount: 35)
    json = {model_field_uid: :cil_value, operator: "nq", value: :cil_contract_amount}.to_json
    vr = ValidationRuleFieldFormat.create!( name: "Name", description: "Description", rule_attributes_json:json)
    expect(vr.run_validation(commercial_invoice_line)).to eq "#{ModelField.find_by_uid(:cil_value).label} must match '35.0' format but was '35.0'."
    commercial_invoice_line.update_attribute(:contract_amount, 6)
    json = {model_field_uid: :cil_value, operator: "nq", value: :cil_contract_amount}.to_json
    vr = ValidationRuleFieldFormat.create!(name: "Name", description: "Description", rule_attributes_json:json)
    expect(vr.run_validation(commercial_invoice_line)).to be_nil
  end

  it "validates two fields when secondary_model_field_uid is present" do
    commercial_invoice_line = Factory(:commercial_invoice_line, value: 10, contract_amount: 5)
    json = {model_field_uid: :cil_value, operator: "gtfdec", secondary_model_field_uid: :cil_contract_amount, value: '10'}.to_json
    vr = ValidationRuleFieldFormat.create!( name: "Name", description: "Description", rule_attributes_json:json)
    expect(vr.run_validation(commercial_invoice_line)).to eq "#{ModelField.find_by_uid(:cil_value).label} must match '10' format but was '100.0'."
    json = {model_field_uid: :cil_value, operator: "gtfdec", secondary_model_field_uid: :cil_contract_amount, value: '200'}.to_json
    vr = ValidationRuleFieldFormat.create!(name: "Name", description: "Description", rule_attributes_json:json)
    expect(vr.run_validation(commercial_invoice_line)).to be_nil
  end
  it "should validate a field by regex" do
    json = {model_field_uid: :ord_ord_num, regex:'X.*Y'}.to_json
    vr = ValidationRuleFieldFormat.create!( name: "Name", description: "Description", rule_attributes_json:json)
    expect(vr.run_validation(Order.new(order_number:'XabcY'))).to be_nil
    expect(vr.run_validation(Order.new(order_number:'Xabc'))).to eq "#{ModelField.find_by_uid(:ord_ord_num).label} must match 'X.*Y' format but was 'Xabc'."
  end
  it "should skip if doesn't match search criterions" do
    json = {model_field_uid: :ord_ord_num, regex:'X.*Y'}.to_json
    vr = ValidationRuleFieldFormat.create!( name: "Name", description: "Description", rule_attributes_json:json)
    vr.search_criterions.build(model_field_uid:'ord_ord_num',operator:'eq',value:'XabcY')
    expect(vr.should_skip?(Order.new(order_number:'XabcY'))).to be_falsey
    expect(vr.should_skip?(Order.new(order_number:'XabcdY'))).to be_truthy
  end
  context "blank" do
    it "should not allow blank" do
      json = {model_field_uid: :ord_ord_num, regex:'X.*Y'}.to_json
      vr = ValidationRuleFieldFormat.create!( name: "Name", description: "Description", rule_attributes_json:json)
      expect(vr.run_validation(Order.new)).to eq "#{ModelField.find_by_uid(:ord_ord_num).label} must match 'X.*Y' format but was ''."
    end
    it "should allow blank if allow_blank is true" do
      json = {model_field_uid: :ord_ord_num, regex:'X.*Y', allow_blank: true}.to_json
      vr = ValidationRuleFieldFormat.create!( name: "Name", description: "Description", rule_attributes_json:json)
      expect(vr.run_validation(Order.new)).to be_nil
    end
  end
end
