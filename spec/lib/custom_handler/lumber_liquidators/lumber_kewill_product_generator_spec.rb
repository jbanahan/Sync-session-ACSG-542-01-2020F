require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberKewillProductGenerator do

  describe "sync_fixed_position" do
    let (:us) { Factory(:country, iso_code: "US")}
    let (:product) {
      p = Factory(:product, unique_identifier: "0000000123", name: "Description")
      c = p.classifications.create! country: us
      c.tariff_records.create! hts_1: "12345678"

      p
    }

    after :each do
      @tempfile.close! if @tempfile && !@tempfile.closed?
    end

    it "finds files to sync and sends them" do
      product 
      @tempfile = subject.sync_fixed_position
      expect(@tempfile).not_to be_nil
      @tempfile.rewind
      file = @tempfile.readlines
      expect(file.length).to eq 1
      expect(file[0][0, 15]).to eq "123            "
      expect(file[0][15, 40]).to eq "Description                             "
      expect(file[0][55, 10]).to eq "12345678  "
      # Make sure nothing comes after the name field
      expect(file[0][66]).to be_nil

      product.reload
      expect(product.sync_records.where(trading_partner: "Kewill").length).to eq 1
    end

    it "does not sync previously synced products" do
      product.sync_records.create! sent_at: Time.zone.now, trading_partner: "Kewill", confirmed_at: (Time.zone.now + 1.minute)
      expect(subject.sync_fixed_position).to be_nil
    end
  end
end