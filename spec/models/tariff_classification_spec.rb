describe TariffClassification do

  describe "find_effective_tariff" do
    subject { described_class }
    let (:country) { FactoryBot(:country) }
    let (:tariff) { FactoryBot(:tariff_classification, country: country, tariff_number: "1234567890", effective_date_start: Date.new(2019, 1, 1))}
    let! (:tariff_rate) { FactoryBot(:tariff_classification_rate, tariff_classification: tariff)}

    it "finds tariff and eager loads the rates" do
      t = subject.find_effective_tariff country, Date.new(2019, 1, 1), "1234567890"
      expect(t).to eq tariff
      expect(t.association(:tariff_classification_rates)).to be_loaded
    end

    it "finds tariff and doesn't eager loads the rates" do
      t = subject.find_effective_tariff country, Date.new(2019, 1, 1), "1234567890", include_rates: false
      expect(t).to eq tariff
      expect(t.association(:tariff_classification_rates)).not_to be_loaded
    end

    it "returns nil if no tariffs found by effective date start" do
      expect(subject.find_effective_tariff country, Date.new(2018, 12, 31), "1234567890").to be_nil
    end

    it "returns nil if no tariffs found by effective date end" do
      tariff.update_attributes! effective_date_end: Date.new(2010, 1, 2)
      expect(subject.find_effective_tariff country, Date.new(2019, 1, 3), "1234567890").to be_nil
    end

    it "returns nil if no tariffs found by number" do
      expect(subject.find_effective_tariff country, Date.new(2019, 1, 3), "12345678").to be_nil
    end

    it "returns the record with the effective date closest to the given date" do
      another_tariff = FactoryBot(:tariff_classification, country: country, tariff_number: "1234567890", effective_date_start: Date.new(2019, 1, 2))
      expect(subject.find_effective_tariff country, Date.new(2019, 1, 10), "1234567890").to eq another_tariff
    end

    it "allows using country iso string" do
      expect(subject.find_effective_tariff country.iso_code, Date.new(2019, 1, 1), "1234567890").to eq tariff
    end

    it "allows using country id" do
      expect(subject.find_effective_tariff country.id, Date.new(2019, 1, 1), "1234567890").to eq tariff
    end
  end

  describe "extract_tariff_rate_data" do

    subject {
      c = TariffClassification.new tariff_number: "1234567890", effective_date_start: Date.new(2001, 1, 1), unit_of_measure_1: "CM", unit_of_measure_2: "KG", duty_computation: "7"
      c.tariff_classification_rates << TariffClassificationRate.new(rate_advalorem: BigDecimal("0.10"), rate_specific: BigDecimal(".50"), rate_additional: BigDecimal("1.00"), special_program_indicator: "01")
      c.tariff_classification_rates << TariffClassificationRate.new(rate_advalorem: BigDecimal("999.99"), rate_specific: BigDecimal("999.99"), rate_additional: BigDecimal("999.99"), special_program_indicator: "02")
      c.tariff_classification_rates << TariffClassificationRate.new(rate_advalorem: BigDecimal("0.50"), rate_specific: BigDecimal("1.25"), rate_additional: BigDecimal("3.55"), special_program_indicator: "JO")
      c.tariff_classification_rates << TariffClassificationRate.new(rate_advalorem: BigDecimal("0.15"), rate_specific: BigDecimal("0.25"), rate_additional: BigDecimal("1.55"), special_program_indicator: "MX")
      c
    }

    it "extracts rate data from classification for Duty Free case" do
      subject.duty_computation = "0"
      d = subject.extract_tariff_rate_data "CN", ""
      expect(d[:advalorem_rate]).to eq BigDecimal("0")
      expect(d[:specific_rate]).to eq BigDecimal("0")
      expect(d[:specific_rate_uom]).to be_nil
      expect(d[:additional_rate]).to eq BigDecimal("0")
      expect(d[:additional_rate_uom]).to be_nil
    end

    ["KP", "CU"].each do |country|

      it "extracts rate data for Column 2 country #{country}" do
        d = subject.extract_tariff_rate_data "#{country}", ""
        expect(d[:advalorem_rate]).to eq BigDecimal("999.99")
        expect(d[:specific_rate]).to eq BigDecimal("0")
        expect(d[:specific_rate_uom]).to be_nil
        expect(d[:additional_rate]).to eq BigDecimal("0")
        expect(d[:additional_rate_uom]).to be_nil
      end
    end

    it "extracts rate data for SPI country" do
      d = subject.extract_tariff_rate_data "JO", "JO"
      expect(d[:advalorem_rate]).to eq BigDecimal("0.50")
      expect(d[:specific_rate]).to eq BigDecimal("0")
      expect(d[:specific_rate_uom]).to be_nil
      expect(d[:additional_rate]).to eq BigDecimal("0")
      expect(d[:additional_rate_uom]).to be_nil
    end

    it "extracts rate data for duty computation 1" do
      subject.duty_computation = "1"
      d = subject.extract_tariff_rate_data "CN", ""
      expect(d[:advalorem_rate]).to eq BigDecimal("0")
      expect(d[:specific_rate]).to eq BigDecimal("0.50")
      expect(d[:specific_rate_uom]).to eq "CM"
      expect(d[:additional_rate]).to eq BigDecimal("0")
      expect(d[:additional_rate_uom]).to be_nil
    end

    it "extracts rate data for duty computation 2" do
      subject.duty_computation = "2"
      d = subject.extract_tariff_rate_data "CN", ""
      expect(d[:advalorem_rate]).to eq BigDecimal("0")
      expect(d[:specific_rate]).to eq BigDecimal("0.50")
      expect(d[:specific_rate_uom]).to eq "KG"
      expect(d[:additional_rate]).to eq BigDecimal("0")
      expect(d[:additional_rate_uom]).to be_nil
    end

    it "extracts rate data for duty computation 3" do
      subject.duty_computation = "3"
      d = subject.extract_tariff_rate_data "CN", ""
      expect(d[:advalorem_rate]).to eq BigDecimal("0")
      expect(d[:specific_rate]).to eq BigDecimal("0.50")
      expect(d[:specific_rate_uom]).to eq "CM"
      expect(d[:additional_rate]).to eq BigDecimal("1.00")
      expect(d[:additional_rate_uom]).to eq "KG"
    end

    it "extracts rate data for duty computation 4" do
      subject.duty_computation = "4"
      d = subject.extract_tariff_rate_data "CN", ""
      expect(d[:advalorem_rate]).to eq BigDecimal("0.1")
      expect(d[:specific_rate]).to eq BigDecimal("0.50")
      expect(d[:specific_rate_uom]).to eq "CM"
      expect(d[:additional_rate]).to eq BigDecimal("0.00")
      expect(d[:additional_rate_uom]).to be_nil
    end

    it "extracts rate data for duty computation 5" do
      subject.duty_computation = "5"
      d = subject.extract_tariff_rate_data "CN", ""
      expect(d[:advalorem_rate]).to eq BigDecimal("0.1")
      expect(d[:specific_rate]).to eq BigDecimal("0.50")
      expect(d[:specific_rate_uom]).to eq "KG"
      expect(d[:additional_rate]).to eq BigDecimal("0.00")
      expect(d[:additional_rate_uom]).to be_nil
    end

    it "extracts rate data for duty computation 6" do
      subject.duty_computation = "6"
      d = subject.extract_tariff_rate_data "CN", ""
      expect(d[:advalorem_rate]).to eq BigDecimal("0.1")
      expect(d[:specific_rate]).to eq BigDecimal("0.50")
      expect(d[:specific_rate_uom]).to eq "CM"
      expect(d[:additional_rate]).to eq BigDecimal("1.00")
      expect(d[:additional_rate_uom]).to eq "KG"
    end

    it "extracts rate data for duty computation 7" do
      subject.duty_computation = "7"
      d = subject.extract_tariff_rate_data "CN", ""
      expect(d[:advalorem_rate]).to eq BigDecimal("0.1")
      expect(d[:specific_rate]).to eq BigDecimal("0")
      expect(d[:specific_rate_uom]).to be_nil
      expect(d[:additional_rate]).to eq BigDecimal("0")
      expect(d[:additional_rate_uom]).to be_nil
    end
  end
end