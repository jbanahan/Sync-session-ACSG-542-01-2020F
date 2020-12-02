describe OpenChain::CustomHandler::AnnInc::AnnValidationRuleProductTariffPercentsAddTo100 do
  let(:rule) { described_class.new }
  let(:cdefs) { rule.cdefs }
  let!(:us) { create(:country, iso_code: "US") }

  let(:prod) { create(:product) }
  let(:classi) do
    cl = create(:classification, product: prod, country: us)
    co = cl.country; co.name = "United States"; co.save!
    cl.update_custom_value! cdefs[:classification_type], "Multi"
    cl
  end
  let!(:tariff_1) do
    t = create(:tariff_record, classification: classi, line_number: 1)
    t.update_custom_value! cdefs[:percent_of_value], 60
    t
  end
  let!(:tariff_2) do
    t = create(:tariff_record, classification: classi, line_number: 2)
    t.update_custom_value! cdefs[:percent_of_value], 40
    t
  end

  describe "run_validation" do
    it "passes if tariff percentages sum to 100 when Classification Type is 'Multi'" do
      expect(rule.run_validation prod).to be_nil
    end

    it "passes if tariff percentages don't sum to 100 when Classification Type isn't 'Multi'" do
      classi.update_custom_value! cdefs[:classification_type], "Decision"
      tariff_2.update_custom_value! cdefs[:percent_of_value], 45
      expect(rule.run_validation prod).to be_nil
    end

    it "fails if tariff percentages don't sum to 100 when Classification Type is 'Multi'" do
      tariff_2.update_custom_value! cdefs[:percent_of_value], 45
      expect(rule.run_validation prod).to eq "The sum of all Percent of Value fields for a Style should equal 100%."
    end
  end

end
