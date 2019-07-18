describe OpenChain::CustomHandler::AnnInc::AnnValidationRuleProductOneTariff do
  let(:rule) { described_class.new }
  let(:cdefs) { rule.cdefs }
  
  let(:prod) { Factory(:product) }
  let(:classi_1) do 
    cl = Factory(:classification, product: prod)
    cl.find_and_set_custom_value cdefs[:classification_type], "Multi"
    cl.save!
    Factory(:tariff_record, classification: cl, line_number: 1)
    Factory(:tariff_record, classification: cl, line_number: 2)
    cl
  end
  
  let(:classi_2) do 
    cl = Factory(:classification, product: prod)
    cl.find_and_set_custom_value cdefs[:classification_type], "Not Applicable"
    Factory(:tariff_record, classification: cl, line_number: 1)
    cl.save!
    cl
  end

  before { classi_1; classi_2 }

  it "passes if Classification Type not set and there is one tariff" do
    expect(rule.run_validation prod).to be_nil
  end

  it "fails if Classification Type not set and there are multiple tariffs" do
    Factory(:tariff_record, classification: classi_2, line_number: 2)
    expect(rule.run_validation prod).to eq "If Classification Type has not been set, only one HTS Classification should exist." 
  end

end

