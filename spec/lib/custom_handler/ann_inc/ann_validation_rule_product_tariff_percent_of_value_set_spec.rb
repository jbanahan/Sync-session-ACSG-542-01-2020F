describe OpenChain::CustomHandler::AnnInc::AnnValidationRuleProductTariffPercentOfValueSet do
  let(:rule) { described_class.new }
  let(:cdefs) { rule.cdefs }
  let!(:us) { create(:country, iso_code: "US")}

  let(:prod) { create(:product) }
  let(:classi) do
    cl = create(:classification, product: prod, country: us)
    co = cl.country; co.name = "United States"; co.save!
    cl.update_custom_value! cdefs[:classification_type], "Multi"
    cl
  end
  let!(:tariff_1) do
    t = create(:tariff_record, classification: classi, line_number: 1)
    t.update_custom_value! cdefs[:percent_of_value], 20
    t
  end
  let!(:tariff_2) do
    t = create(:tariff_record, classification: classi, line_number: 2)
    t.update_custom_value! cdefs[:percent_of_value], 30
    t
  end

  describe "run_validation" do
    it "passes if all tariffs have Percent of Value when Classification Type is 'Multi'" do
      expect(rule.run_validation prod).to be_nil
    end

    it "passes if a tariff has no Percent of Value when Classification Type isn't 'Multi'" do
      classi.update_custom_value! cdefs[:classification_type], "Decision"
      tariff_1.update_custom_value! cdefs[:percent_of_value], nil
      expect(rule.run_validation prod).to be_nil
    end

    it "fails if a tariff has a blank Percent of Value when Classification Type is 'Multi'" do
      tariff_1.update_custom_value! cdefs[:percent_of_value], nil
      expect(rule.run_validation prod).to eq %Q(If Classification Type equals "Multi", Percent of Value is a required field.\nUnited States, line 1)
    end

    it "fails if a tariff 0 Percent of Value when Classification Type is 'Multi'" do
      tariff_1.update_custom_value! cdefs[:percent_of_value], 0
      expect(rule.run_validation prod).to eq %Q(If Classification Type equals "Multi", Percent of Value is a required field.\nUnited States, line 1)
    end
  end
end
