describe OpenChain::CustomHandler::UnderArmour::UaSubsProductGenerator do
  before :each do
    @cdefs = described_class.prep_custom_definitions [:prod_site_codes]
    @p = create(:product, unique_identifier: "123-456-7890")
    @p.update_custom_value! @cdefs[:prod_site_codes], "123"
    cl = create(:classification, product: @p, country: create(:country, iso_code: "CN"))
    @t = create(:tariff_record, classification: cl, hts_1: "1234.56.7890")
  end

  describe "sync_csv" do
    after :each do
      @f.close! if @f && !@f.closed?
    end

    it "generates a csv file without site data" do
      DataCrossReference.create!(key: "123", value: "US", cross_reference_type: "ua_site")
      site = create(:classification, product: @p, country: create(:country, iso_code: "US"))
      create(:tariff_record, classification: site, hts_1: "0987.65.4321")

      g = described_class.new
      @f = g.sync_csv
      out = CSV.read @f.path

      expect(out.length).to eq 2
      expect(out.first).to eq ["Country", "Article", "Classification"]
      expect(out.second).to eq ["CN", "123-456-7890", "1234.56.7890"]

      expect(SyncRecord.where(syncable_id: @p.id, trading_partner: g.sync_code).first).not_to be_nil
    end

    it "excludes results with a blank hts" do
      @t.update_attributes(hts_1: "")
      g = described_class.new
      expect(g.sync_csv).to be_nil
      expect(SyncRecord.where(syncable_id: @p.id, trading_partner: g.sync_code).first).to be_nil
    end

    it "excludes subs lacking a tariff" do
      sub = create(:classification, product: @p, country: create(:country, iso_code: "PK"))
      create(:tariff_record, classification: sub, hts_1: "")

      g = described_class.new
      @f = g.sync_csv
      out = CSV.read @f.path

      expect(out.length).to eq 2
      expect(out.first).to eq ["Country", "Article", "Classification"]
      expect(out.second).to eq ["CN", "123-456-7890", "1234.56.7890"]
    end
  end
end