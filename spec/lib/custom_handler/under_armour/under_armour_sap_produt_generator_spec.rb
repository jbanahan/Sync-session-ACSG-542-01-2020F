require 'spec_helper'

describe OpenChain::CustomHandler::UnderArmour::UnderArmourSapProductGenerator do

  describe "sync_csv" do
    before :each do
      @t = Factory(:tariff_record, hts_1: "1234567890")
    end

    after :each do
      @f.close! if @f && !@f.closed?
    end

    it "generates a csv file" do
      g = described_class.new
      @f = g.sync_csv
      out = CSV.read @f.path

      expect(out.length).to eq 2
      expect(out.first).to eq ["Country of Destination", "Material", "HTS Code", "Duty Rate"]
      expect(out.second).to eq [@t.classification.country.iso_code, @t.product.unique_identifier, @t.hts_1.hts_format, ""]

      expect(SyncRecord.where(syncable_id: @t.product.id, trading_partner: g.sync_code).first).not_to be_nil
    end

    it "uses Expected Duty Rate if given" do
      g = described_class.new
      edr_cd = g.class.prep_custom_definitions([:expected_duty_rate])[:expected_duty_rate]
      @t.classification.update_custom_value! edr_cd, 25.5

      @f = g.sync_csv
      out = CSV.read @f.path
      expect(out.second).to eq [@t.classification.country.iso_code, @t.product.unique_identifier, @t.hts_1.hts_format, "25.5"]
    end

    it "uses cross reference rate if no expected duty rate found" do
      DataCrossReference.create! key: "#{@t.classification.country.iso_code}*~*#{@t.hts_1}", value: "123", cross_reference_type: DataCrossReference::UA_DUTY_RATE

      @f = described_class.new.sync_csv
      out = CSV.read @f.path
      expect(out.length).to eq 2
      expect(out.second).to eq [@t.classification.country.iso_code, @t.product.unique_identifier, @t.hts_1.hts_format, "123.0"]
    end

    it "falls back to official tariff rate" do
      OfficialTariff.create! hts_code: @t.hts_1, country_id: @t.classification.country_id, general_rate: "1.25%"

      @f = described_class.new.sync_csv
      out = CSV.read @f.path
      expect(out.length).to eq 2
      expect(out.second).to eq [@t.classification.country.iso_code, @t.product.unique_identifier, @t.hts_1.hts_format, "1.25"]
    end

    it "handles footnotes in official tariff rate" do
      OfficialTariff.create! hts_code: @t.hts_1, country_id: @t.classification.country_id, general_rate: "1.25% 1/ 2/"

      @f = described_class.new.sync_csv
      out = CSV.read @f.path
      expect(out.length).to eq 2
      expect(out.second).to eq [@t.classification.country.iso_code, @t.product.unique_identifier, @t.hts_1.hts_format, "1.25"]
    end

    it "skips non-advalorem official tariff rates" do
      OfficialTariff.create! hts_code: @t.hts_1, country_id: @t.classification.country_id, general_rate: "1.25¢/kg + 1.25%"
      @f = described_class.new.sync_csv
      out = CSV.read @f.path
      expect(out.length).to eq 2
      expect(out.second).to eq [@t.classification.country.iso_code, @t.product.unique_identifier, @t.hts_1.hts_format, ""]
    end

    it "translates FREE to 0 in official tariff rates" do
      OfficialTariff.create! hts_code: @t.hts_1, country_id: @t.classification.country_id, general_rate: "FREE"
      @f = described_class.new.sync_csv
      out = CSV.read @f.path
      expect(out.length).to eq 2
      expect(out.second).to eq [@t.classification.country.iso_code, @t.product.unique_identifier, @t.hts_1.hts_format, "0.0"]
    end

    it "prefers Expected duty rate over xref and official tariff" do
      g = described_class.new
      edr_cd = g.class.prep_custom_definitions([:expected_duty_rate])[:expected_duty_rate]
      @t.classification.update_custom_value! edr_cd, 25.5
      DataCrossReference.create! key: "#{@t.classification.country.iso_code}*~*#{@t.hts_1}", value: "123", cross_reference_type: DataCrossReference::UA_DUTY_RATE
      OfficialTariff.create! hts_code: @t.hts_1, country_id: @t.classification.country_id, general_rate: "1.25%"

      @f = g.sync_csv
      out = CSV.read @f.path
      expect(out.second).to eq [@t.classification.country.iso_code, @t.product.unique_identifier, @t.hts_1.hts_format, "25.5"]
    end

    it "prefers xref over official tariff" do
      g = described_class.new
      DataCrossReference.create! key: "#{@t.classification.country.iso_code}*~*#{@t.hts_1}", value: "123", cross_reference_type: DataCrossReference::UA_DUTY_RATE
      OfficialTariff.create! hts_code: @t.hts_1, country_id: @t.classification.country_id, general_rate: "1.25%"

      @f = g.sync_csv
      out = CSV.read @f.path
      expect(out.second).to eq [@t.classification.country.iso_code, @t.product.unique_identifier, @t.hts_1.hts_format, "123.0"]
    end
  end

  describe "run_schedulable" do
    before :each do
      @t = Factory(:tariff_record, hts_1: "1234567890")
    end

    it "ftps sync'ed file" do
      out = nil
      described_class.any_instance.should_receive(:ftp_file) do |f|
        begin
          out = CSV.read f.path
        ensure
          f.close!
        end
      end

      described_class.run_schedulable
      expect(out.second).to eq [@t.classification.country.iso_code, @t.product.unique_identifier, @t.hts_1.hts_format, ""]
    end
  end
end