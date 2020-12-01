describe ValidationRuleEntryFishWildlifeTransmittedDateFilled do
  describe "run_validation" do
    let(:rule) { described_class.new(name: "rule name", description: "rule desc") }

    let(:cdefs) { described_class.new.cdefs }
    let(:imp) { FactoryBot(:company) }
    let(:entry) { FactoryBot(:entry, importer: imp) }
    let(:invoice_1) { FactoryBot(:commercial_invoice, entry: entry, invoice_number: "123456")}
    let!(:line_1) { FactoryBot(:commercial_invoice_line, commercial_invoice: invoice_1, line_number: 1) }
    let(:invoice_2) { FactoryBot(:commercial_invoice, entry: entry, invoice_number: "654321") }
    let!(:line_2) { FactoryBot(:commercial_invoice_line, commercial_invoice: invoice_2, line_number: 1) }
    let!(:line_2_2) { FactoryBot(:commercial_invoice_line, commercial_invoice: invoice_2, line_number: 2) }

    let!(:product_1) { FactoryBot(:product, importer: imp, unique_identifier: "attr_part_1")}
    let!(:product_2) { FactoryBot(:product, importer: imp, unique_identifier: "attr_part_2")}
    let!(:product_3) { FactoryBot(:product, importer: imp, unique_identifier: "attr_part_3")}
    let(:cdef_fw) { cdefs[:prod_fish_wildlife] }
    let!(:cval_fw_1) { CustomValue.create! custom_definition: cdef_fw, customizable: product_1, boolean_value: true }
    let!(:cval_fw_2) { CustomValue.create! custom_definition: cdef_fw, customizable: product_2, boolean_value: true }
    let!(:cval_fw_3) { CustomValue.create! custom_definition: cdef_fw, customizable: product_3, boolean_value: false }

    context "vandegrift instance" do
      before do
        ms = stub_master_setup
        allow(ms).to receive(:custom_feature?).with("WWW").and_return true

        line_1.update_attributes! part_number: "cdef_part_1"
        line_2.update_attributes! part_number: "cdef_part_2"
        line_2_2.update_attributes! part_number: "cdef_part_3"
      end
      let!(:cdef_part_no) { cdefs[:prod_part_number] }
      let!(:cval_part_no_1) { CustomValue.create! custom_definition: cdef_part_no, customizable: product_1, string_value: "cdef_part_1" }
      let!(:cval_part_no_2) { CustomValue.create! custom_definition: cdef_part_no, customizable: product_2, string_value: "cdef_part_2" }
      let!(:cval_part_no_3) { CustomValue.create! custom_definition: cdef_part_no, customizable: product_3, string_value: "cdef_part_3" }

      it "fails and returns all invoice/line/part numbers" do
        expect(rule.run_validation entry).to eq "Fish and Wildlife Transmission Date missing but F&W products found:\ninvoice 123456 / line 1 / part cdef_part_1\ninvoice 654321 / line 1 / part cdef_part_2"
      end

      it "uses different importer for products, if specified" do
        imp = FactoryBot(:company, system_code: "ACME")
        product_2.update_attributes! importer_id: imp.id

        rule.rule_attributes_json = {importer_system_code: "ACME"}.to_json; rule.save!
        expect(rule.run_validation entry).to eq "Fish and Wildlife Transmission Date missing but F&W products found:\ninvoice 654321 / line 1 / part cdef_part_2"
      end

      it "passes if no product with flag is found" do
        cval_fw_1.update_attributes! boolean_value: false
        cval_fw_2.update_attributes! boolean_value: false
        expect(rule.run_validation entry).to be_nil
      end

      it "passes if product is found and f&w date is present" do
        entry.update_attributes! fish_and_wildlife_transmitted_date: Date.new(2019, 3, 15)
        expect(rule.run_validation entry).to be_nil
      end
    end

    context "other instances" do
      before do
        ms = stub_master_setup
        allow(ms).to receive(:custom_feature?).with("WWW").and_return false

        line_1.update_attributes! part_number: "attr_part_1"
        line_2.update_attributes! part_number: "attr_part_2"
        line_2_2.update_attributes! part_number: "attr_part_3"
      end

      it "fails and returns all invoice/line/part numbers" do
        expect(rule.run_validation entry).to eq "Fish and Wildlife Transmission Date missing but F&W products found:\ninvoice 123456 / line 1 / part attr_part_1\ninvoice 654321 / line 1 / part attr_part_2"
      end

      it "uses different importer for products, if specified" do
        imp = FactoryBot(:company, system_code: "ACME")
        product_2.update_attributes! importer_id: imp.id

        rule.rule_attributes_json = {importer_system_code: "ACME"}.to_json; rule.save!
        expect(rule.run_validation entry).to eq "Fish and Wildlife Transmission Date missing but F&W products found:\ninvoice 654321 / line 1 / part attr_part_2"
      end

      it "passes if no product with flag is found" do
        cval_fw_1.update_attributes! boolean_value: false
        cval_fw_2.update_attributes! boolean_value: false
        expect(rule.run_validation entry).to be_nil
      end

      it "passes if product is found and f&w date is present" do
        entry.update_attributes! fish_and_wildlife_transmitted_date: Date.new(2019, 3, 15)
        expect(rule.run_validation entry).to be_nil
      end
    end
  end
end
