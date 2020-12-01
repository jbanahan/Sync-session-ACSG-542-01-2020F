describe ValidationRuleOrderLineProductFieldFormat do
  it "should fail when product doesn't match" do
    p = FactoryBot(:product, unique_identifier:'px')
    ol = FactoryBot(:order_line, product:p)
    json = {model_field_uid: :prod_uid, regex: "ABC"}.to_json
    vr = described_class.create!(name: "Name", description: "Description", rule_attributes_json:json)

    expect(vr.run_validation(ol.order)).not_to be_blank
  end
  it "should pass when product does match" do
    p = FactoryBot(:product, unique_identifier:'ABC')
    ol = FactoryBot(:order_line, product:p)
    json = {model_field_uid: :prod_uid, regex: "ABC"}.to_json
    vr = described_class.create!(name: "Name", description: "Description", rule_attributes_json:json)

    expect(vr.run_validation(ol.order)).to be_nil
  end

  context "fail_if_matches" do
    let(:vr) { described_class.create!(name: "Name", description: "Description", rule_attributes_json:{model_field_uid: :prod_uid, regex: "ABC", fail_if_matches: true}.to_json)  }

    it "fails when product matches" do
      p = FactoryBot(:product, unique_identifier:'ABC')
      ol = FactoryBot(:order_line, product:p)

      expect(vr.run_validation(ol.order)).to eq "At least one Unique Identifier value matches 'ABC' format for Product ABC."
    end

    it "passes when product doesn't match" do
      p = FactoryBot(:product, unique_identifier:'px')
      ol = FactoryBot(:order_line, product:p)

      expect(vr.run_validation(ol.order)).to be_nil
    end
  end
end
