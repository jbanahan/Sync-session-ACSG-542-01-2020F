describe OpenChain::CustomHandler::AnnInc::AnnValidationRuleProductClassTypeSet do
  let(:prod) { Factory(:product) }
  let!(:us) { Factory(:country, iso_code: "US") }
  let(:classi) do 
    cl = Factory(:classification, product: prod, country: us)
    cl.find_and_set_custom_value cdefs[:manual_flag], true
    cl.find_and_set_custom_value cdefs[:classification_type], "Multi"
    cl.save!
    cl
  end

  let(:rule) { described_class.new }
  let(:cdefs) { rule.cdefs }

  describe "run_validation" do
    it "passes when all classifications with 'Manual Entry Processing' have 'Classification Type' set" do
      classi;
      expect(rule.run_validation prod).to be_nil

      classi.update_custom_value! cdefs[:classification_type], "Decision"
      expect(rule.run_validation prod).to be_nil
    end

    it "passes if classification without 'Manual Entry Processing' is missing a 'Classification Type'" do
      classi.find_and_set_custom_value cdefs[:manual_flag], false
      classi.find_and_set_custom_value cdefs[:classification_type], "Not Applicable"
      classi.save!

      expect(rule.run_validation prod).to be_nil
    end

    it "fails if any classification with 'Manual Entry Processing' is missing a 'Classification Type'" do
      classi.update_custom_value! cdefs[:classification_type], "Not Applicable"     

      expect(rule.run_validation prod).to eq "If the Manual Entry Processing checkbox is checked, Classification Type is required."
    end
  end

end
