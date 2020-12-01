describe OfficialTariffMetaDatum do

  describe "official_tariff" do
    before :each do
      @country = FactoryBot(:country, :iso_code=>'XY')
      @officialtariff = FactoryBot(:official_tariff, country: @country, hts_code: "1234578906")
      @tariff_datum = FactoryBot(:official_tariff_meta_datum, country: @country, hts_code: "1234578906")
    end

    it "should return the associated official tariff object" do
      expect(@tariff_datum.official_tariff).to eq @officialtariff
    end
  end
end
