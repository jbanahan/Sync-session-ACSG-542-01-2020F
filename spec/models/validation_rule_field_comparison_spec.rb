describe ValidationRuleFieldComparison do

  it "validates a field with specified operator/operand" do
    json = {model_field_uid: :ent_total_packages, operator: "gt", value: 5}.to_json
    vr = ValidationRuleFieldComparison.create!( name: "Name", description: "Description", rule_attributes_json:json)
    expect(vr.run_validation(Entry.new(total_packages: 6))).to be_nil
    expect(vr.run_validation(Entry.new(total_packages: 4))).to eq "#{ModelField.find_by_uid(:ent_total_packages).label} greater than '5' is required but was '4'."
  end
  it "should skip if doesn't match search criterions" do
    json = {model_field_uid: :ent_total_packages, operator:'gt', value: 5}.to_json
    vr = ValidationRuleFieldComparison.create!( name: "Name", description: "Description", rule_attributes_json:json)
    vr.search_criterions.build(model_field_uid: :ent_total_packages, operator:'gt', value: 5)
    expect(vr.should_skip?(Entry.new(total_packages: 6))).to be_falsey
    expect(vr.should_skip?(Entry.new(total_packages: 4))).to be_truthy
  end
  context "blank" do
    it "should not allow blank" do
      json = {model_field_uid: :ent_total_packages, operator:'gt', value: 5}.to_json
      vr = ValidationRuleFieldComparison.create!( name: "Name", description: "Description", rule_attributes_json:json)
      expect(vr.run_validation(Entry.new)).to eq "#{ModelField.find_by_uid(:ent_total_packages).label} greater than '5' is required but was ''."
    end
    it "should allow blank if allow_blank is true" do
      json = {model_field_uid: :ent_total_packages, operator:'gt', allow_blank: true}.to_json
      vr = ValidationRuleFieldComparison.create!( name: "Name", description: "Description", rule_attributes_json:json)
      expect(vr.run_validation(Entry.new)).to be_nil
    end
  end
end
