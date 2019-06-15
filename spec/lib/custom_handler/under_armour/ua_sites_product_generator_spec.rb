describe OpenChain::CustomHandler::UnderArmour::UaSitesProductGenerator do
  before :each do
    @cdefs = described_class.prep_custom_definitions [:prod_site_codes]
    @p = Factory(:product, unique_identifier: "123-456-7890")
    @p.update_custom_value! @cdefs[:prod_site_codes], "123"
    cl1 = Factory(:classification, product: @p, country: Factory(:country, iso_code: "US"))
    cl2 = Factory(:classification, product: @p, country: Factory(:country, iso_code: "CN"))
    @t1 = Factory(:tariff_record, classification: cl1, hts_1: "1234567890")
    @t2 = Factory(:tariff_record, classification: cl2, hts_1: "0987654321")
    DataCrossReference.create!(key: "123", value: "US", cross_reference_type: "ua_site")
  end
  
  describe "sync_csv" do
    after :each do
      @f.close! if @f && !@f.closed?
    end

    it "generates a csv file with a row for each matching site code" do
      non_site_cl = Factory(:classification, product: @p, country: Factory(:country, iso_code: "CA"))
      Factory(:tariff_record, classification: non_site_cl, hts_1: "1357935791")
      DataCrossReference.create!(key: "234", value: "CN", cross_reference_type: "ua_site")
      @p.update_custom_value! @cdefs[:prod_site_codes], "123\n 234"
      
      g = described_class.new
      @f = g.sync_csv
      out = CSV.read @f.path

      expect(out.length).to eq 3
      expect(out.first).to eq ["Article", "Site Code", "Classification"]
      expect(out.second).to eq ["123-456-7890", "123", "1234.56.7890"]
      expect(out.third).to eq ["123-456-7890", "234", "0987.65.4321"]

      expect(SyncRecord.where(syncable_id: @p.id, trading_partner: g.sync_code).first).not_to be_nil
    end

    it "shows same data if assigned more than one site code" do
      DataCrossReference.create!(key: "234", value: "US", cross_reference_type: "ua_site")
      @p.update_custom_value! @cdefs[:prod_site_codes], "123\n 234"

      g = described_class.new
      @f = g.sync_csv
      out = CSV.read @f.path

      expect(out.length).to eq 3
      expect(out.first).to eq ["Article", "Site Code", "Classification"]
      expect(out.second).to eq ["123-456-7890", "123", "1234.56.7890"]
      expect(out.third).to eq ["123-456-7890", "234", "1234.56.7890"]

      expect(SyncRecord.where(syncable_id: @p.id, trading_partner: g.sync_code).first).not_to be_nil
    end

    it "excludes results with a blank hts" do
      @t1.update_attributes(hts_1: "")
      g = described_class.new
      expect(g.sync_csv).to be_nil
      expect(SyncRecord.where(syncable_id: @p.id, trading_partner: g.sync_code).first).to be_nil
    end

    it "excludes results with blank site codes" do
      @p.update_custom_value! @cdefs[:prod_site_codes], ""
      g = described_class.new
      expect(g.sync_csv).to be_nil
      expect(SyncRecord.where(syncable_id: @p.id, trading_partner: g.sync_code).first).to be_nil
    end

    it "excludes sites lacking a tariff" do
      DataCrossReference.create!(key: "234", value: "CN", cross_reference_type: "ua_site")
      @p.update_custom_value! @cdefs[:prod_site_codes], "123\n 234"
      @t2.update_attributes(hts_1: nil)

      g = described_class.new
      @f = g.sync_csv
      out = CSV.read @f.path

      expect(out.length).to eq 2
      expect(out.second).to eq ["123-456-7890", "123", "1234.56.7890"]
    end

    it "excludes sites lacking a classification" do
      DataCrossReference.create!(key: "234", value: "CN", cross_reference_type: "ua_site")
      @p.update_custom_value! @cdefs[:prod_site_codes], "123\n 234"
      @t2.classification.destroy

      g = described_class.new
      @f = g.sync_csv
      out = CSV.read @f.path

      expect(out.length).to eq 2
      expect(out.second).to eq ["123-456-7890", "123", "1234.56.7890"]
    end
  end
end