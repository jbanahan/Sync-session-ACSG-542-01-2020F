describe ValidationRuleEntryInvoiceLineTariffFieldFormat do

  describe "run_validation" do
    before :each do
      json = {model_field_uid: :cit_hts_code, regex:'\d{4}'}.to_json
      @rule = ValidationRuleEntryInvoiceLineTariffFieldFormat.new rule_attributes_json:json
    end

    it "validates tariff level field formats" do
      tariff = Factory(:commercial_invoice_tariff, hts_code: "1234")
      expect(@rule.run_validation tariff.commercial_invoice_line.entry).to be_nil
    end

    it "reports invalid field formats" do
      tariff = Factory(:commercial_invoice_tariff, hts_code: "ABC")
      expect(@rule.run_validation tariff.commercial_invoice_line.entry).to eq "All #{ModelField.find_by_uid(:cit_hts_code).label} values do not match '\\d{4}' format."
    end

    it "reports only reports one invalid field formats" do
      # Just make sure we're stopping after a single line fails
      tariff = Factory(:commercial_invoice_tariff, hts_code: "ABC")
      tariff2 = Factory(:commercial_invoice_tariff, hts_code: "ABC", commercial_invoice_line: tariff.commercial_invoice_line)
      tariff3 = Factory(:commercial_invoice_tariff, hts_code: "ABC", commercial_invoice_line: Factory(:commercial_invoice_line, commercial_invoice: tariff.commercial_invoice_line.commercial_invoice))

      expect(@rule.run_validation tariff.commercial_invoice_line.entry).to eq "All #{ModelField.find_by_uid(:cit_hts_code).label} values do not match '\\d{4}' format."
    end

    it "filters at the invoice line level (not tariff level)" do
      tariff = Factory(:commercial_invoice_tariff, hts_code: "ABC")
      tariff.commercial_invoice_line.update_attributes! part_number: "ABC"
      @rule.search_criterions.build model_field_uid: 'cil_part_number', operator: 'eq', value: '123'

      # if the rule was evaluated this would fail, but since the part number doesn't match the criterion, it will pass
      expect(@rule.run_validation tariff.commercial_invoice_line.entry).to be_nil
    end

    it "runs validations on the tariff when criterions match invoice line" do
      tariff = Factory(:commercial_invoice_tariff, hts_code: "ABC")
      tariff.commercial_invoice_line.update_attributes! part_number: "ABC"
      @rule.search_criterions.build model_field_uid: 'cil_part_number', operator: 'eq', value: 'ABC'

      # if the rule was evaluated this would fail, but since the part number doesn't match the criterion, it will pass
      expect(@rule.run_validation tariff.commercial_invoice_line.entry).to eq "All #{ModelField.find_by_uid(:cit_hts_code).label} values do not match '\\d{4}' format."
    end
  end
end