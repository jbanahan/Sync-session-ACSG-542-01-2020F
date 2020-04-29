describe OpenChain::AntiVirus::TestingAntiVirus do
  subject { described_class }

  describe "registered" do
    it "raises an error if attempted to be used in production" do
      expect(MasterSetup).to receive(:production_env?).and_return true
      expect { subject.registered }.to raise_error "The TestingAntiVirus implementation cannot be utilized in production."
    end

    it "allows usage in non-prod environments" do
      expect(MasterSetup).to receive(:production_env?).and_return false
      subject.registered
      expect(subject.scan_value).to eq true
    end
  end

  describe "safe?" do
    around :each do |ex|
      v = OpenChain::AntiVirus::TestingAntiVirus.scan_value
      begin
        ex.run
      ensure
        OpenChain::AntiVirus::TestingAntiVirus.scan_value = v
      end
    end

    before :each do
      OpenChain::AntiVirus::TestingAntiVirus.scan_value = "safe"
    end

    it "returns configured value" do
      expect(subject.safe? "/fake/file.txt").to eq "safe"
    end
  end
end