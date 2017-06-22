require 'spec_helper'

describe OpenChain::CustomHandler::UnderArmour::UaSubsProductGenerator do
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

    it "generates a csv file" do
      g = described_class.new
      @f = g.sync_csv
      out = CSV.read @f.path

      expect(out.length).to eq 2
      expect(out.first).to eq ["Country", "Article", "Classification"]
      expect(out.second).to eq ["CN", "123-456-7890", "0987654321"]

      expect(SyncRecord.where(syncable_id: @p.id, trading_partner: g.sync_code).first).not_to be_nil
    end

    it "excludes results with a blank hts" do
      @t2.update_attributes(hts_1: "")
      g = described_class.new
      expect(g.sync_csv).to be_nil
      expect(SyncRecord.where(syncable_id: @p.id, trading_partner: g.sync_code).first).to be_nil
    end
  end

  describe "run" do
    it "ftps sync'ed file" do
      out = nil
      expect_any_instance_of(described_class).to receive(:ftp_file) do |instance, f|
        begin
          out = IO.binread f.path
        ensure
          f.close!
        end
      end

      described_class.run
      #Make sure we're sending Windows newlines
      expect(StringIO.new(out).gets[-2, 2]).to eq "\r\n"
      csv = []
      CSV.parse(out) {|row| csv << row}
      expect(csv.second).to eq ["CN", "123-456-7890", "0987654321"]
    end
  end  
end