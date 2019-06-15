describe ValidationRuleEntryInvoiceLineTariffFieldFormat do

  describe "run_validation" do
    before :each do
      json = {model_field_uid: :cit_hts_code, regex:'\d{4}'}.to_json
      @rule = ValidationRuleEntryInvoiceLineTariffFieldFormat.new rule_attributes_json:json
    end

    it "validates tariff level field formats" do
      tariff = Factory(:commercial_invoice_tariff, hts_code: "1234", commercial_invoice_line: Factory(:commercial_invoice_line, line_number: 1, commercial_invoice: Factory(:commercial_invoice, invoice_number: "INV")))
      expect(@rule.run_validation tariff.commercial_invoice_line.entry).to be_nil
    end

    it "reports invalid field formats" do
      tariff = Factory(:commercial_invoice_tariff, hts_code: "ABC", commercial_invoice_line: Factory(:commercial_invoice_line, line_number: 1, commercial_invoice: Factory(:commercial_invoice, invoice_number: "INV")))
      expect(@rule).to receive(:stop_validation)
      expect(@rule.run_validation tariff.commercial_invoice_line.entry).to eq "Invoice # INV / Line # 1 #{ModelField.find_by_uid(:cit_hts_code).label} value 'ABC' does not match '\\d{4}' format."
    end

    it "reports invalid field formats" do
      tariff = Factory(:commercial_invoice_tariff, hts_code: "ABC", commercial_invoice_line: Factory(:commercial_invoice_line, line_number: 1, commercial_invoice: Factory(:commercial_invoice, invoice_number: "INV")))
      @rule.rule_attributes_json = {model_field_uid: :cit_hts_code, regex:'\d{4}', validate_all: true}.to_json
      expect(@rule).not_to receive(:stop_validation)
      expect(@rule.run_validation tariff.commercial_invoice_line.entry).to eq "Invoice # INV / Line # 1 #{ModelField.find_by_uid(:cit_hts_code).label} value 'ABC' does not match '\\d{4}' format."
    end

    context "fail_if_matches" do
      let(:rule) { ValidationRuleEntryInvoiceLineTariffFieldFormat.new rule_attributes_json:{model_field_uid: :cit_hts_code, regex:'\d{4}', fail_if_matches: true}.to_json }

      it "validates tariff-level field formats" do
        tariff = Factory(:commercial_invoice_tariff, hts_code: "abcd", commercial_invoice_line: Factory(:commercial_invoice_line, line_number: 1, commercial_invoice: Factory(:commercial_invoice, invoice_number: "INV")))
        expect(rule.run_validation tariff.commercial_invoice_line.entry).to be_nil
      end

      it "reports invalid field formats" do
        tariff = Factory(:commercial_invoice_tariff, hts_code: "1234", commercial_invoice_line: Factory(:commercial_invoice_line, line_number: 1, commercial_invoice: Factory(:commercial_invoice, invoice_number: "INV")))
        expect(rule.run_validation tariff.commercial_invoice_line.entry).to eq "Invoice # INV / Line # 1 #{ModelField.find_by_uid(:cit_hts_code).label} value should not match '\\d{4}' format."
      end
    end

    it "reports only reports one invalid field formats" do
      # Just make sure we're stopping after a single line fails
      tariff = Factory(:commercial_invoice_tariff, hts_code: "ABC", commercial_invoice_line: Factory(:commercial_invoice_line, line_number: 1, commercial_invoice: Factory(:commercial_invoice, invoice_number: "INV")))
      tariff2 = Factory(:commercial_invoice_tariff, hts_code: "ABC", commercial_invoice_line: tariff.commercial_invoice_line)
      tariff3 = Factory(:commercial_invoice_tariff, hts_code: "ABC", commercial_invoice_line: Factory(:commercial_invoice_line, line_number: 2, commercial_invoice: tariff.commercial_invoice_line.commercial_invoice))
      expect(@rule).to receive(:stop_validation).and_call_original
      expect(@rule.run_validation tariff.commercial_invoice_line.entry).to eq "Invoice # INV / Line # 1 #{ModelField.find_by_uid(:cit_hts_code).label} value 'ABC' does not match '\\d{4}' format."
    end

    it "filters at the invoice line level (not tariff level)" do
      tariff = Factory(:commercial_invoice_tariff, hts_code: "ABC")
      tariff.commercial_invoice_line.update_attributes! part_number: "ABC"
      @rule.search_criterions.build model_field_uid: 'cil_part_number', operator: 'eq', value: '123'

      # if the rule was evaluated this would fail, but since the part number doesn't match the criterion, it will pass
      expect(@rule.run_validation tariff.commercial_invoice_line.entry).to be_nil
    end

    it "runs validations on the tariff when criterions match invoice line" do
      tariff = Factory(:commercial_invoice_tariff, hts_code: "ABC", commercial_invoice_line: Factory(:commercial_invoice_line, line_number: 1, commercial_invoice: Factory(:commercial_invoice, invoice_number: "INV")))
      tariff.commercial_invoice_line.update_attributes! part_number: "ABC"
      @rule.search_criterions.build model_field_uid: 'cil_part_number', operator: 'eq', value: 'ABC'

      # if the rule was evaluated this would fail, but since the part number doesn't match the criterion, it will pass
      expect(@rule.run_validation tariff.commercial_invoice_line.entry).to eq "Invoice # INV / Line # 1 #{ModelField.find_by_uid(:cit_hts_code).label} value 'ABC' does not match '\\d{4}' format."
    end
  end
end
