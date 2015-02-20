require 'spec_helper'

describe OpenChain::CustomHandler::UnderArmour::UaProductApiSyncGenerator do

  describe "sync" do
    before :each do 
      @api_client = double("FakeProductApiClient")
      tariff = Factory(:tariff_record, line_number: 1, hts_1: "1234567890", classification: Factory(:classification, country: Factory(:country, iso_code: "US")))
      @product = tariff.product
      @g = described_class.new api_client: @api_client
      @cdefs = described_class.prep_custom_definitions([:plant_codes, :colors])
    end


    it "syncs new objects to vfi track" do
      # Set up the product so it has 3 colors, but only 2 to send (ie only set up 2 ua materiacl color plant xrefs)
      @product.update_custom_value! @cdefs[:colors], "A\nB\nC"
      @product.update_custom_value! @cdefs[:plant_codes], "US Plant\nCA Plant"

      DataCrossReference.create! cross_reference_type: DataCrossReference::UA_PLANT_TO_ISO, key: "US Plant", value: "US"
      DataCrossReference.create! cross_reference_type: DataCrossReference::UA_PLANT_TO_ISO, key: "CA Plant", value: "CA"
      DataCrossReference.create_ua_material_color_plant! @product.unique_identifier, "A", "US Plant"
      DataCrossReference.create_ua_material_color_plant! @product.unique_identifier, "B", "US Plant"

      # We're going to mock out the data for the remote calls
      @api_client.should_receive(:find_by_uid).with("UNDAR-" + "#{@product.unique_identifier}-A", ["prod_uid", "*cf_43", "class_cntry_iso", "hts_line_number", "hts_hts_1", "prod_imp_syscode"]).and_return({'product'=>nil})
      @api_client.should_receive(:find_by_uid).with("UNDAR-" + "#{@product.unique_identifier}-B", ["prod_uid", "*cf_43", "class_cntry_iso", "hts_line_number", "hts_hts_1", "prod_imp_syscode"]).and_return({'product'=>nil})

      # Capture and analyze the remote data later
      create_data = []
      @api_client.should_receive(:create).exactly(2).times do |data|
        create_data << data
        nil
      end

      @g.sync

      # Validate the data sent to api
      expect(create_data.first).to eq ({ 'product' => {
        'prod_uid' => "UNDAR-#{@product.unique_identifier}-A",
        'prod_imp_syscode' => "UNDAR",
        '*cf_43' => "#{@product.unique_identifier}-A",
        'classifications' => [{
          'class_cntry_iso' => @product.classifications.first.country.iso_code,
          'tariff_records' => [{
            'hts_line_number' => 1,
            'hts_hts_1' => @product.classifications.first.tariff_records.first.hts_1.hts_format
          }]
        }]
      }})

      expect(create_data.second).to eq ({ 'product' => {
        'prod_uid' => "UNDAR-#{@product.unique_identifier}-B",
        'prod_imp_syscode' => "UNDAR",
        '*cf_43' => "#{@product.unique_identifier}-B",
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
      #validate that fingerprinting is not being used for these
      expect(sr.fingerprint).to be_nil
    end
  end
end