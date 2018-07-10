describe SpecialTariffCrossReference do

  describe "before_validation / clean_hts" do
    it "strips non-hts chars from attribute on validation" do
      hts = described_class.new hts_number: "1234.56.7890", special_hts_number: "0987.65.4321"
      hts.valid?
      expect(hts.hts_number).to eq "1234567890"
      expect(hts.special_hts_number).to eq "0987654321"
    end
  end

  describe SpecialTariffCrossReference::SpecialTariffHash do 

    before :each do 
      subject.insert SpecialTariffCrossReference.new(hts_number: "1234567890", special_hts_number: "0987654321")
      subject.insert SpecialTariffCrossReference.new(hts_number: "1234567", special_hts_number: "987654") 
    end

    describe "[]" do
      it "returns a matching special tariff" do
        ref = subject["1234567890"]
        expect(ref.special_hts_number).to eq "0987654321"
      end

      it "finds best matching special tariff" do
        ref = subject["1234567000"]
        expect(ref.special_hts_number).to eq "987654"
      end
    end
  end

  describe "find_special_tariff_hash" do
    subject { described_class }

    let!(:special_tariff) { SpecialTariffCrossReference.create! hts_number: "12345678", country_origin_iso: "CN", special_hts_number: "0987654321", effective_date_start: Date.new(2018, 7, 9), effective_date_end: Date.new(2018, 8, 1)}

    it "returns all special tariffs with effective dates after given date" do
      result = subject.find_special_tariff_hash reference_date: Date.new(2018, 7, 9)
      expect(result.size).to eq 1
      expect(result["CN"]).to be_a SpecialTariffCrossReference::SpecialTariffHash
      expect(result["CN"]["1234567890"]).to eq special_tariff
    end

    it "excludes tariffs with start date after reference date" do
      result = subject.find_special_tariff_hash reference_date: Date.new(2018, 7, 1)
      expect(result.size).to eq 0
    end

    it "excludes tariffs with end date prior to reference date" do
      result = subject.find_special_tariff_hash reference_date: Date.new(2018, 8, 9)
      expect(result.size).to eq 0
    end

    it "excludes tariffs not for given country of origin" do
      result = subject.find_special_tariff_hash reference_date: Date.new(2018, 7, 9), country_origin_iso: "US"
      expect(result.size).to eq 0
    end
  end
end