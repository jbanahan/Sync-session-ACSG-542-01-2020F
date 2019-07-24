describe OpenChain::CustomHandler::AnnInc::AnnValidationRuleProductTariffKeyDescriptionSet do
  let(:rule) { described_class.new }
  let(:cdefs) { rule.cdefs }
  let!(:us) { Factory(:country, iso_code: "US") }

  let(:prod) { Factory(:product) }
  let(:classi) do
    cl = Factory(:classification, product: prod, country: us)
    co = cl.country; co.name = "United States"; co.save!
    cl.update_custom_value! cdefs[:classification_type], "Multi"
    cl
  end
  let!(:tariff_1) do
    t = Factory(:tariff_record, classification: classi, line_number: 1)
    t.update_custom_value! cdefs[:key_description], "description 1"
    t
  end
  let!(:tariff_2) do
    t = Factory(:tariff_record, classification: classi, line_number: 2)
    t.update_custom_value! cdefs[:key_description], "description 2"
    t
  end

  describe "run_validation" do
    it "passes if Classification Type is 'Multi' and every tariff has a Key Description" do
      expect(rule.run_validation prod).to be_nil
    end

    it "passes if Classification Type is 'Decision' and every tariff has a Key Description" do
      classi.update_custom_value! cdefs[:classification_type], "Decision"
      expect(rule.run_validation prod).to be_nil
    end

    it "passes if Classification Type is 'Not Applicable' and a tariff is missing a Key Description" do
      classi.update_custom_value! cdefs[:classification_type], "Not Applicable"
      tariff_2.update_custom_value! cdefs[:key_description], nil
      expect(rule.run_validation prod).to be_nil
    end

    it "fails if Classification Type is 'Multi' and a tariff is missing a Key Description" do
      tariff_2.update_custom_value! cdefs[:key_description], nil
      expect(rule.run_validation prod).to eq %Q(If Classification Type equals "Multi" or "Decision", Key Description is a required field.\nUnited States, line 2)
    end

    it "fails if Classification Type is 'Decision' and a tariff is missing a Key Description" do
      classi.update_custom_value! cdefs[:classification_type], "Decision"
      tariff_2.update_custom_value! cdefs[:key_description], nil
      expect(rule.run_validation prod).to eq %Q(If Classification Type equals "Multi" or "Decision", Key Description is a required field.\nUnited States, line 2)
    end
  end

end
