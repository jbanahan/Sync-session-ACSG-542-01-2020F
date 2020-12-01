describe OpenChain::CustomHandler::Hm::ValidationRuleHmInvoiceLineFieldFormat do
  let!(:ci) { FactoryBot(:commercial_invoice, invoice_number: "12345") }

  context "with regex" do
    let(:rule) { described_class.new(rule_attributes_json:{model_field_uid: "cil_value", regex: "12.34"}.to_json) }
    let!(:ci_line_1) { FactoryBot(:commercial_invoice_line, commercial_invoice: ci, value: 12.34, subheader_number: 1, customs_line_number: 2, part_number:'ABC123') }
    let!(:ci_line_2) { FactoryBot(:commercial_invoice_line, commercial_invoice: ci, value: 12.34, subheader_number: 3, customs_line_number: 4, part_number:'321CBA') }

    it "passes if all lines match regex" do
      expect(rule.run_validation(ci.entry)).to be_nil
    end

    it "fails if any line doesn't match regex" do
      ci_line_2.update_attributes(value: 11.00)
      FactoryBot(:commercial_invoice_line, commercial_invoice: ci, value: 5.23, subheader_number: 5, customs_line_number: 6, part_number:'CBA321')
      expect(rule.run_validation(ci.entry)).to eq "On the following invoice line(s) 'Invoice Line - Value' doesn't match format '12.34':\nInvoice # 12345: B3 Sub Hdr # 3 / B3 Line # 4 / part 321CBA\nInvoice # 12345: B3 Sub Hdr # 5 / B3 Line # 6 / part CBA321"
    end

    it "returns only lines with unique inv# / subheader / line / part combination" do
      ci_line_2.update_attributes(value: 11.00)
      FactoryBot(:commercial_invoice_line, commercial_invoice: ci, value: 9.00, subheader_number: 3, customs_line_number: 4, part_number:'321CBA')
      expect(rule.run_validation(ci.entry)).to eq "On the following invoice line(s) 'Invoice Line - Value' doesn't match format '12.34':\nInvoice # 12345: B3 Sub Hdr # 3 / B3 Line # 4 / part 321CBA"
    end
  end

  context "with NOT regex" do
    let(:rule) { described_class.new(rule_attributes_json:{model_field_uid: "cil_value", not_regex: "12.34"}.to_json) }
    let!(:ci_line_1) { FactoryBot(:commercial_invoice_line, commercial_invoice: ci, value: 11.00, subheader_number: 1, customs_line_number: 2, part_number:'ABC123') }
    let!(:ci_line_2) { FactoryBot(:commercial_invoice_line, commercial_invoice: ci, value: 12.48, subheader_number: 3, customs_line_number: 4, part_number:'321CBA') }

    it "passes if no lines match regex" do
      expect(rule.run_validation(ci.entry)).to be_nil
    end

    it "fails if any line matches regex" do
      ci_line_2.update_attributes(value: 12.34)
      FactoryBot(:commercial_invoice_line, value: 12.34, commercial_invoice: ci, subheader_number: 5, customs_line_number: 6, part_number:'CBA321')
      expect(rule.run_validation(ci.entry)).to eq "On the following invoice line(s) 'Invoice Line - Value' matches format '12.34':\nInvoice # 12345: B3 Sub Hdr # 3 / B3 Line # 4 / part 321CBA\nInvoice # 12345: B3 Sub Hdr # 5 / B3 Line # 6 / part CBA321"
    end
  end
end