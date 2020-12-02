describe ValidationRuleEntryInvoiceLineMatchesProduct do
  let(:json) { {product_model_field_uid: "prod_uom", line_model_field_uid: "cil_uom"}.to_json }
  let!(:rule) { described_class.new rule_attributes_json: json }

  let(:part_num_cdef) { create(:custom_definition, data_type: "string", module_type: "Product", cdef_uid: "prod_part_number") }

  let(:imp) { create(:company) }

  let!(:product) do
    prod = create(:product, unit_of_measure: "lb", importer: imp)
    prod.update_custom_value! part_num_cdef, "part num"
    prod
  end

  let!(:line) do
    ln = create(:commercial_invoice_line, unit_of_measure: "lb", part_number: "part num")
    ln.entry.update! importer: imp
    ln.reload
  end

  it "passes if line and product value do match" do
    expect(rule.run_child_validation(line)).to be_nil
  end

  it "searches for products under a different importer, if specified" do
    imp2 = create(:company, system_code: "ACME")
    product.update! importer_id: imp2.id
    json = {product_model_field_uid: "prod_uom", line_model_field_uid: "cil_uom", product_importer_system_code: "ACME"}.to_json
    rule.assign_attributes rule_attributes_json: json
    expect(rule.run_child_validation(line)).to be_nil
  end

  it "fails if a product isn't found" do
    product.update_custom_value! part_num_cdef, "part num 2"
    expect(rule.run_child_validation(line)).to eq %(No part number "part num" found.)
  end

  it "fails if line and product value don't match" do
    line.update! unit_of_measure: "kg"
    expect(rule.run_child_validation(line)).to eq %(Expected Invoice Line - UOM to be "lb" but found "kg".)
  end

end
