describe OpenChain::CustomHandler::Vandegrift::KewillTariffClassificationsParser do

  let! (:us) { FactoryBot(:country, iso_code: "US") }

  let (:tariff_json) {
    [
      {
          "tariff_no" => "1006204060",
          "date_tariff_effective" => 20121031,
          "date_tariff_expiration" => 20991231,
          "no_of_rpt_units" => 1,
          "uom_1" => "KG",
          "uom_2" => "CM",
          "uom_3" => "IN",
          "duty_computation" => "1",
          "base_rate_indicator" => "Y",
          "tariff_desc" => "RICE: SHT GRAIN OTH HUSKD BRN",
          "countervailing_duty_flag" => "N",
          "antidumping_duty_flag" => "N",
          "blocked_record" => 0,
          "extract_time" => "2019-01-29t12:13:07-05:00",
          "tariff_rates" => [
              {
                  "country_code_column" => "01",
                  "rate_specific" => 2100000,
                  "rate_advalorem" => 12345678,
                  "rate_additional" => 987654321
              },
              {
                  "country_code_column" => "02",
                  "rate_specific" => 3300000,
                  "rate_advalorem" => 0,
                  "rate_additional" => 0
              }
          ]
      }
    ]
  }

  describe "parse_json" do
    let! (:inbound_file) {
      f = InboundFile.new
      allow(subject).to receive(:inbound_file).and_return f
      f
    }

    it "parses tariff json and saves data" do
      subject.parse_json tariff_json

      c = TariffClassification.where(country_id: us.id, tariff_number: "1006204060", effective_date_start: Date.new(2012, 10, 31)).first
      expect(c).not_to be_nil

      expect(c.effective_date_end).to eq Date.new(2099, 12, 31)
      expect(c.number_of_reporting_units).to eq BigDecimal("1")
      expect(c.unit_of_measure_1).to eq "KG"
      expect(c.unit_of_measure_2).to eq "CM"
      expect(c.unit_of_measure_3).to eq "IN"
      expect(c.duty_computation).to eq "1"
      expect(c.base_rate_indicator).to eq "Y"
      expect(c.tariff_description).to eq "RICE: SHT GRAIN OTH HUSKD BRN"
      expect(c.countervailing_duty).to eq false
      expect(c.antidumping_duty).to eq false
      expect(c.blocked_record).to eq false

      expect(c.tariff_classification_rates.length).to eq 2

      r = c.tariff_classification_rates.first
      expect(r.special_program_indicator).to eq "01"
      expect(r.rate_advalorem).to eq BigDecimal("0.12345678")
      expect(r.rate_specific).to eq BigDecimal("0.021")
      expect(r.rate_additional).to eq BigDecimal("9.87654321")

      r = c.tariff_classification_rates.second
      expect(r.special_program_indicator).to eq "02"
      expect(r.rate_advalorem).to eq BigDecimal("0")
      expect(r.rate_specific).to eq BigDecimal("0.033")
      expect(r.rate_additional).to eq BigDecimal("0")

      expect(inbound_file).to have_info_message("Processed 1 tariff update.")
    end

    it "handles true boolean values in json" do
      tariff_json[0]["countervailing_duty_flag"] = "Y"
      tariff_json[0]["antidumping_duty_flag"] = "Y"
      tariff_json[0]["blocked_record"] = 1

      subject.parse_json tariff_json

      c = TariffClassification.where(country_id: us.id, tariff_number: "1006204060", effective_date_start: Date.new(2012, 10, 31)).first
      expect(c).not_to be_nil
      expect(c.countervailing_duty).to eq true
      expect(c.antidumping_duty).to eq true
      expect(c.blocked_record).to eq true
    end

    it "handles 9999 tariff rates" do
      tariff_json[0]["tariff_rates"][0]["rate_advalorem"] = "999999999999"

      subject.parse_json tariff_json
      c = TariffClassification.where(country_id: us.id, tariff_number: "1006204060", effective_date_start: Date.new(2012, 10, 31)).first
      expect(c).not_to be_nil

      r = c.tariff_classification_rates.first
      expect(r.rate_advalorem).to be_nil
    end
  end
end