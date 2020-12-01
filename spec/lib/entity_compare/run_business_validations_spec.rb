describe OpenChain::EntityCompare::RunBusinessValidations do

  subject { described_class }

  describe "compare" do
    it "calls BusinessValidationTemplate.create_results_for_object!" do
      ord = FactoryBot(:order)
      expect(OpenChain::EntityCompare::CascadeProductValidations).to receive(:compare).with('Order', ord.id, 'a', 'b', 'c', 'd', 'e', 'f')
      expect(OpenChain::EntityCompare::CascadeCompanyValidations).to receive(:compare).with('Order', ord.id, 'a', 'b', 'c', 'd', 'e', 'f')
      subject.compare 'Order', ord.id, 'a', 'b', 'c', 'd', 'e', 'f'
    end
  end

  describe "accept?" do
    it "accepts by default" do
      expect(subject.accept?(EntitySnapshot.new)).to eq true
    end

    it "does not accept if cascading is disabled" do
      ms = stub_master_setup
      expect(ms).to receive(:custom_feature?).with("Disable Cascading Validations").and_return true
      expect(subject.accept?(EntitySnapshot.new)).to eq false
    end
  end

end