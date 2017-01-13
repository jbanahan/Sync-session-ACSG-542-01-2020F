require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberKewillProductGenerator do

  describe "run_schedulable" do
    subject { described_class }

    let (:us) { Factory(:country, iso_code: "US")}
    let (:importer) { Factory(:importer, alliance_customer_number: "LUMBER")}
    let! (:product) {
      p = Factory(:product, importer: importer, unique_identifier: "0000000123", name: "Description")
      c = p.classifications.create! country: us
      c.tariff_records.create! hts_1: "12345678"

      p
    }

    it "finds files to sync and sends them" do
      data = nil
      expect_any_instance_of(subject).to receive(:ftp_file) do |instance, file|
        data = file.read
      end

      subject.run_schedulable

      expect(data).not_to be_nil
      doc = REXML::Document.new(data)

      parent = REXML::XPath.first doc, "/requests/request/kcData/parts/part"
      expect(parent.text "id/partNo").to eq "123"
      expect(parent.text "id/custNo").to eq "LUMBER"
      expect(parent.text "id/dateEffective").to eq "20140101"
      expect(parent.text "dateExpiration").to eq "20991231"
      expect(parent.text "styleNo").to eq "123"
      expect(parent.text "descr").to eq "Description"
      expect(parent.text "CatTariffClassList/CatTariffClass/seqNo").to eq "1"
      expect(parent.text "CatTariffClassList/CatTariffClass/tariffNo").to eq "12345678"
    end

    it "does not sync previously synced products" do
      product.sync_records.create! sent_at: Time.zone.now, trading_partner: "Kewill", confirmed_at: (Time.zone.now + 1.minute)
      expect_any_instance_of(subject).not_to receive(:ftp_file)
      subject.run_schedulable
    end
  end
end