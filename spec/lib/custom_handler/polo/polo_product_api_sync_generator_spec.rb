require 'spec_helper'

describe OpenChain::CustomHandler::Polo::PoloProductApiSyncGenerator do

  describe "sync" do

    before :each do
      @api_client = double("FakeProductApiClient")
      @c = described_class.new api_client: @api_client

      tariff = Factory(:tariff_record, hts_1: "1234567890", classification: Factory(:classification, country: Factory(:country, iso_code: "CA")))
      @product = tariff.product
    end

    it "syncs a product to another VFI Track instance" do
      # Since the specifics for a single product api sync generator are minimal, just do a single overview test
      # to ensure the expected values are sent/received.  The class this generator extends does the vast majority of
      # the work involved and is thoroughly tested already.

      # We're going to mock out the data for the remote calls
      @api_client.should_receive(:find_by_uid).with("RLMASTER-" + @product.unique_identifier,["prod_uid", "*cf_43", "class_cntry_iso", "hts_line_number", "hts_hts_1", "prod_imp_syscode"]).and_return({'product'=>nil})

      # Capture and analyze the remote data later
      remote_data = nil
      @api_client.should_receive(:create) do |data|
        remote_data = data
        nil
      end

      @c.sync

      # Validate the remote data
      expect(remote_data).to eq ({ 'product' => {
        'prod_uid' => "RLMASTER-#{@product.unique_identifier}",
        'prod_imp_syscode' => "RLMASTER",
        '*cf_43' => @product.unique_identifier,
        'classifications' => [{
          'class_cntry_iso' => @product.classifications.first.country.iso_code,
          'tariff_records' => [{
            'hts_line_number' => 1,
            'hts_hts_1' => @product.classifications.first.tariff_records.first.hts_1.hts_format
          }]
        }]
      }})

      sr = @product.reload.sync_records.first
      expect(sr).not_to be_nil
      # Just validate the trading partner, every other aspect of the sync record data is the responsibility
      # of the parent class of the one we're testing
      expect(sr.trading_partner).to eq "vfitrack"
    end
  end
end