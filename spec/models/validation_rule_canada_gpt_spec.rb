require 'spec_helper'

describe ValidationRuleCanadaGpt do

  describe "run_validation" do
    before :each do
      @t = Factory(:commercial_invoice_tariff, hts_code: "1234567890", spi_primary: "0", commercial_invoice_line: Factory(:commercial_invoice_line, country_origin_code: "ZZ"))
      @l = @t.commercial_invoice_line
      @entry = @l.entry
      @canada = Factory(:country, iso_code: "CA")
      @official_tariff = OfficialTariff.create! country_id: @canada.id, hts_code: @t.hts_code, special_rates: "(GPT)"
    end

    it "passes when non-GPT country is used" do
      expect(described_class.new.run_validation @entry).to be_nil
    end

    it "fails when GPT country is used without 9 tariff treatment" do
      @l.update_attributes! country_origin_code: "AF"
      expect(described_class.new.run_validation @entry).to eq "Tariff Treatment should be set to 9 when HTS qualifies for special GPT rates.  Country: #{@l.country_origin_code} HTS: #{@t.hts_code}"
    end

    it "passes when 9 tariff treatment is used" do
      @l.update_attributes! country_origin_code: "AF"
      @t.update_attributes! spi_primary: "9"

      expect(described_class.new.run_validation @entry).to be_nil
    end

    it "passes when official tariff does not include special GPT rates" do
      @l.update_attributes! country_origin_code: "AF"
      @official_tariff.update_attributes! special_rates: "NONE"

      expect(described_class.new.run_validation @entry).to be_nil
    end

    it "stops after recording a single error on the tariff" do
      @l.update_attributes! country_origin_code: "AF"
      t2 =  Factory(:commercial_invoice_tariff, hts_code: "1234567890", spi_primary: "0", commercial_invoice_line: @l)

      expect(described_class.new.run_validation @entry).to eq "Tariff Treatment should be set to 9 when HTS qualifies for special GPT rates.  Country: #{@l.country_origin_code} HTS: #{@t.hts_code}"
    end

    it "stops after recording an error on the first line" do
      # This is mostly just to confirm that stop_validation is called when iterating over the invoice lines
      @l.update_attributes! country_origin_code: "AF"
      t = Factory(:commercial_invoice_tariff, hts_code: "1234567890", spi_primary: "0", commercial_invoice_line: Factory(:commercial_invoice_line, country_origin_code: "AI", commercial_invoice: @l.commercial_invoice))
      expect(described_class.new.run_validation @entry).to eq "Tariff Treatment should be set to 9 when HTS qualifies for special GPT rates.  Country: #{@l.country_origin_code} HTS: #{@t.hts_code}"
    end

    it "caches the official tariff lookup" do
      @l.update_attributes! country_origin_code: "AF"
      rule = described_class.new
      expect(rule.run_validation @entry).to eq "Tariff Treatment should be set to 9 when HTS qualifies for special GPT rates.  Country: #{@l.country_origin_code} HTS: #{@t.hts_code}"

      @official_tariff.destroy
      expect(rule.run_validation @entry).to eq "Tariff Treatment should be set to 9 when HTS qualifies for special GPT rates.  Country: #{@l.country_origin_code} HTS: #{@t.hts_code}"
    end
  end
end