describe InboundFileIdentifier do 

  describe "translate_identifier" do 
    subject { described_class }

    it "allows using symbolized variants of the TYPE_* constants" do
      expect(subject.translate_identifier :article_number).to eq "Article Number"
    end

    it "raises an argument error if the constant doesn't exist" do
      expect{subject.translate_identifier :error }.to raise_error ArgumentError, "InboundFileIdentifier::TYPE_ERROR constant does not exist."
    end

    it "ignores String values" do 
      expect(subject.translate_identifier "test").to eq "test"
    end
  end
end