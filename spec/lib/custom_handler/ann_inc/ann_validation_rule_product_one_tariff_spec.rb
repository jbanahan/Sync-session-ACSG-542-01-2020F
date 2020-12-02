describe OpenChain::CustomHandler::AnnInc::AnnValidationRuleProductOneTariff do
  let(:rule) { described_class.new }
  let(:cdefs) { rule.cdefs }
  let!(:us) { create(:country, iso_code: "US") }

  let(:prod) { create(:product) }
  let!(:classi) do
    cl = create(:classification, product: prod, country: us)
    cl.find_and_set_custom_value cdefs[:classification_type], "Multi"
    cl.save!
    create(:tariff_record, classification: cl, line_number: 1)
    create(:tariff_record, classification: cl, line_number: 2)
    cl
  end

  it "passes if Classification type is set and there are multiple tariffs" do
    expect(rule.run_validation prod).to be_nil
  end

  it "passes if Classification Type not set and there is one tariff" do
    # tariff_records don't get instantiated without this, for some reason
    classi.reload

    classi.update_custom_value! cdefs[:classification_type], "Not Applicable"
    classi.tariff_records.first.destroy
    expect(rule.run_validation prod).to be_nil
  end

  it "fails if Classification Type not set and there are multiple tariffs" do
    classi.update_custom_value! cdefs[:classification_type], "Not Applicable"

    expect(rule.run_validation prod).to eq "If Classification Type has not been set, only one HTS Classification should exist."
  end

end

