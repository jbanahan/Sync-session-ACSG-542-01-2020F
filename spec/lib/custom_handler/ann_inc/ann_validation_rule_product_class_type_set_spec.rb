describe OpenChain::CustomHandler::AnnInc::AnnValidationRuleProductClassTypeSet do
  let(:prod) { Factory(:product) }
  let(:classi_1) do 
    cl = Factory(:classification, product: prod)
    cl.find_and_set_custom_value cdefs[:manual_flag], true
    cl.find_and_set_custom_value cdefs[:classification_type], "Multi"
    cl.save!
    cl
  end
  
  let(:classi_2) do 
    cl = Factory(:classification, product: prod)
    cl.find_and_set_custom_value cdefs[:manual_flag], true
    cl.find_and_set_custom_value cdefs[:classification_type], "Decision"
    cl.save!
    cl
  end

  let(:rule) { described_class.new }
  let(:cdefs) { rule.cdefs }

  describe "run_validation" do
    it "passes when all classifications with 'Manual Entry Processing' have 'Classification Type' set" do
      classi_1; classi_2
      expect(rule.run_validation prod).to be_nil
    end

    it "passes if classification without 'Manual Entry Processing' is missing a 'Classification Type'" do
      classi_1.find_and_set_custom_value cdefs[:manual_flag], false
      classi_1.find_and_set_custom_value cdefs[:classification_type], "Not Applicable"
      classi_1.save!

      expect(rule.run_validation prod).to be_nil
    end

    it "fails if any classification with 'Manual Entry Processing' is missing a 'Classification Type'" do
      classi_1
      classi_2.update_custom_value! cdefs[:classification_type], "Not Applicable"

      expect(rule.run_validation prod).to eq "If the Manual Entry Processing checkbox is checked, Classification Type is required."
    end
  end

end
