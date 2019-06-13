describe ValidationRuleEntryProductInactive do

  describe "run_validation" do
    let(:rule) { described_class.new(name: "rule name", description: "rule desc") }
    let (:custom_defintions) {
      subject.class.prep_custom_definitions [:prod_part_number]
    }

    let(:imp) { Factory(:company, system_code: "NOTACME") }
    let(:entry) { Factory(:entry, importer_id: imp.id) }

    let(:invoice_1) { Factory(:commercial_invoice, entry: entry, invoice_number: "123456") }
    let(:line_1) { Factory(:commercial_invoice_line, commercial_invoice: invoice_1, line_number: 1) }
    let(:invoice_2) { Factory(:commercial_invoice, entry: entry, invoice_number: "654321") }
    let(:line_2) { Factory(:commercial_invoice_line, commercial_invoice: invoice_2, line_number: 2) }
    let(:line_3) { Factory(:commercial_invoice_line, commercial_invoice: invoice_2, line_number: 3) }

    let(:product_1) { Factory(:product, importer: imp, unique_identifier: "PartNUMBER", inactive: false) }
    let(:product_2) { Factory(:product, importer: imp, unique_identifier: "PartNUMBER2", inactive: false) }
    let(:product_3) { Factory(:product, importer: imp, unique_identifier: "PartNUMBER3", inactive: false) }

    let!(:cdef_part_no) { custom_defintions[:prod_part_number] }

    context "vandegrift instance" do
      before do
        line_1.update_attributes! part_number: "cdef_part_1"
        line_2.update_attributes! part_number: "cdef_part_2"
        line_3.update_attributes! part_number: "cdef_part_3"

        product_1.update_custom_value! cdef_part_no, "cdef_part_1"
        product_2.update_custom_value! cdef_part_no, "cdef_part_2"
        product_3.update_custom_value! cdef_part_no, "cdef_part_3"
      end

      let! (:master_setup) {
        ms = stub_master_setup
        allow(ms).to receive(:custom_feature?).with("WWW").and_return true
        ms
      }

      it "uses different importer for products, if specified" do
        imp1 = Factory(:company, system_code: "ACME")
        product_1.update_attributes! importer_id: imp1.id, inactive: true
        product_2.update_attributes! inactive: true

        rule.rule_attributes_json = {importer_system_code: "ACME"}.to_json; rule.save!
        expect(rule.run_validation entry).to eq "Part(s) were found with the inactive (discontinued) flag set:\nInvoice 123456 / Line 1 / Part cdef_part_1"
      end

      it "does not notify if part has inactive (discontinued) flag is set to false" do
        expect(subject.run_validation entry).to be_nil
      end

      it "notfies if part has inactive flag is set to true" do
        product_2.update_attributes! inactive: true

        expect(subject.run_validation entry).to eq "Part(s) were found with the inactive (discontinued) flag set:\nInvoice 654321 / Line 2 / Part cdef_part_2"
      end

      it "includes all parts that have the inactive (discontinued) flag set to true" do
        product_2.update_attributes inactive: true
        product_3.update_attributes inactive: true

        expect(subject.run_validation entry).to eq "Part(s) were found with the inactive (discontinued) flag set:\nInvoice 654321 / Line 2 / Part cdef_part_2\nInvoice 654321 / Line 3 / Part cdef_part_3"
      end
    end

    context "any other instance" do
      before do
        line_1.update_attributes! part_number: "PartNUMBER"
        line_2.update_attributes! part_number: "PartNUMBER2"
        line_3.update_attributes! part_number: "PartNUMBER3"
      end

      let! (:master_setup) {
        ms = stub_master_setup
        allow(ms).to receive(:custom_feature?).with("WWW").and_return false
        ms
      }

      it "does not notify if part has inactive (discontinued) flag is set to false" do
        expect(subject.run_validation entry).to be_nil
      end

      it "uses different importer for products, if specified" do
        imp1 = Factory(:company, system_code: "ACME")
        product_1.update_attributes! importer_id: imp1.id, inactive: true
        product_2.update_attributes! inactive: true

        rule.rule_attributes_json = {importer_system_code: "ACME"}.to_json; rule.save!
        expect(rule.run_validation entry).to eq "Part(s) were found with the inactive (discontinued) flag set:\nInvoice 123456 / Line 1 / Part PartNUMBER"
      end

      it "notfies if part has inactive flag is set to true" do
        product_2.update_attributes inactive: true

        expect(subject.run_validation entry).to eq "Part(s) were found with the inactive (discontinued) flag set:\nInvoice 654321 / Line 2 / Part PartNUMBER2"
      end

      it "includes all parts that have the inactive (discontinued) flag set to true" do
        product_2.update_attributes inactive: true
        product_3.update_attributes inactive: true

        expect(subject.run_validation entry).to eq "Part(s) were found with the inactive (discontinued) flag set:\nInvoice 654321 / Line 2 / Part PartNUMBER2\nInvoice 654321 / Line 3 / Part PartNUMBER3"
      end
    end
  end
end
