describe OpenChain::CustomHandler::UnderArmour::UaProductApiSyncGenerator do

  describe "sync" do
    before :each do
      @api_client = double("FakeProductApiClient")
      @tariff = FactoryBot(:tariff_record, line_number: 1, hts_1: "1234567890", classification: FactoryBot(:classification, country: FactoryBot(:country, iso_code: "US"), product: FactoryBot(:product, name: "Description")))
      @product = @tariff.product
      @g = described_class.new api_client: @api_client
      @cdefs = described_class.prep_custom_definitions([ :colors])
    end


    it "syncs new objects to vfi track" do
      # Set up the product so it has 3 colors listed, but only 2 unique ones
      @product.update_custom_value! @cdefs[:colors], "A\n   \nB\nA"

      # We're going to mock out the data for the remote calls
      expect(@api_client).to receive(:find_by_uid).with("UNDAR-" + "#{@product.unique_identifier}-A", ["prod_uid", "*cf_43", "class_cntry_iso", "hts_line_number", "hts_hts_1", "*cf_99", "prod_imp_syscode"]).and_return({'product'=>nil})
      expect(@api_client).to receive(:find_by_uid).with("UNDAR-" + "#{@product.unique_identifier}-B", ["prod_uid", "*cf_43", "class_cntry_iso", "hts_line_number", "hts_hts_1", "*cf_99", "prod_imp_syscode"]).and_return({'product'=>nil})

      # Capture and analyze the remote data later
      create_data = []
      expect(@api_client).to receive(:create).exactly(2).times do |data|
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
      # validate that fingerprinting is not being used for these
      expect(sr.fingerprint).to be_nil
    end

    it "syncs CA tariffs" do
      @product.update_custom_value! @cdefs[:colors], "A"
      ca = FactoryBot(:country, iso_code: 'CA')
      @tariff.classification.update_attributes! country: ca

      expect(@api_client).to receive(:find_by_uid).with("UNDAR-" + "#{@product.unique_identifier}-A", ["prod_uid", "*cf_43", "class_cntry_iso", "hts_line_number", "hts_hts_1", "*cf_99", "prod_imp_syscode"]).and_return({'product'=>nil})

      create_data = []
      expect(@api_client).to receive(:create).exactly(1).times do |data|
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
          'class_cntry_iso' => "CA",
          '*cf_99' => @product.name,
          'tariff_records' => [{
            'hts_line_number' => 1,
            'hts_hts_1' => @product.classifications.first.tariff_records.first.hts_1.hts_format
          }]
        }]
      }})
    end

    it "saves a sync record for products with no data to sync" do
      # Blank the colors field, so then we don't have anything to split out
      @product.update_custom_value! @cdefs[:colors], "    "
      now = Time.zone.now
      Timecop.freeze(now) { @g.sync }

      sr = @product.reload.sync_records.first
      expect(sr).not_to be_nil
      expect(sr.sent_at.to_i).to eq now.to_i
      expect(sr.confirmed_at.to_i).to eq (now + 1.minute).to_i
      expect(sr.confirmation_file_name).to eq "No US data to send."
    end
  end
end