describe OpenChain::CustomHandler::Hm::HmBusinessLogicSupport do

  subject { 
    Class.new {
      include OpenChain::CustomHandler::Hm::HmBusinessLogicSupport
    }.new
  }

  describe "extract_style_number_from_sku" do 
    it "extracts first 7 digits from a string" do
      expect(subject.extract_style_number_from_sku "1234567890").to eq "1234567"
    end

    it "strips leading zeros on strings over 16 chars long" do
      expect(subject.extract_style_number_from_sku "00000012345678901234567").to eq "1234567"
    end

    it "does not strip leading zeros on strings 16 chars and under" do
      expect(subject.extract_style_number_from_sku "0123456789012345").to eq "0123456"
    end
  end
end