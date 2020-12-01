describe ValidationRuleOrderLineHtsValid do
  let!(:template) { FactoryBot(:business_validation_template, name: "template name")}
  let!(:rule) do
    r = described_class.new(name: "rule name", description: "descr", rule_attributes_json: {iso_code: "US"}.to_json)
    r.business_validation_template = template; r.save!
    r
  end
  let!(:order) { FactoryBot(:order) }
  let!(:ordln_1) { FactoryBot(:order_line, order: order, hts: "123456789", line_number: 1 ) }
  let!(:ordln_2) { FactoryBot(:order_line, order: order, hts: "246810121", line_number: 2 ) }
  let!(:us) { FactoryBot(:country, iso_code: "US") }
  let!(:ca) { FactoryBot(:country, iso_code: "CA") }
  let!(:ot_1) { FactoryBot(:official_tariff, country: us, hts_code: "123456789") }
  let!(:ot_2) { FactoryBot(:official_tariff, country: us, hts_code: "246810121") }
  let!(:ot_3) { FactoryBot(:official_tariff, country: ca, hts_code: "987654321") }

  describe "run_child_validation" do
    it "passes if all lines have a valid HTS for specified country" do
      expect(rule.run_validation(order)).to be_nil
    end

    it "fails if any line doesn't have an HTS associated with specified country" do
      ordln_2.update_attributes! hts: "987654321"
      expect(rule.run_validation(order)).to eq "Invalid HTS code found on line 2: 987654321"
    end

    it "fails if any line has a missing HTS" do
      ordln_2.update_attributes! hts: nil
      expect(rule.run_validation(order)).to eq "Missing HTS code found on line 2."
    end

    it "raises exception if ISO code not specified" do
      rule.update_attributes! rule_attributes_json: nil
      expect { rule.run_validation(order) }.to raise_error "Rule 'rule name' on 'template name' is missing 'iso_code' attribute."
    end

  end

end

