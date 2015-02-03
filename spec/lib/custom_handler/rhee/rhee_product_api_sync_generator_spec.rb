require 'spec_helper'

describe OpenChain::CustomHandler::Rhee::RheeProductApiSyncGenerator do

  describe "sync" do

    before :each do
      @api_client = double("FakeProductApiClient")
      @c = described_class.new api_client: @api_client
      @fda_def = @c.class.prep_custom_definitions([:fda_product_code])[:fda_product_code]

      tariff = Factory(:tariff_record, hts_1: "1234567890", classification: Factory(:classification, country: Factory(:country, iso_code: "US")))
      @product = tariff.product
      @product.update_custom_value! @fda_def, "FDA-123"
    end

    it "syncs product requiring update to a remote VFI Track instance not having that product data" do
      # We're going to mock out the data for the remote calls
      @api_client.should_receive(:find_by_uid).with("RHEE-" + @product.unique_identifier,["prod_uid", "*cf_43", "*cf_78", "*cf_77", "class_cntry_iso", "hts_line_number", "hts_hts_1", "prod_imp_syscode"]).and_return({'product'=>nil})

      # Capture and analyze the remote data later
      remote_data = nil
      @api_client.should_receive(:create) do |data|
        remote_data = data
        nil
      end

      @c.sync

      # Validate the remote data
      expect(remote_data).to eq ({ 'product' => {
        'prod_uid' => "RHEE-#{@product.unique_identifier}",
        'prod_imp_syscode' => "RHEE",
        '*cf_43' => @product.unique_identifier,
        '*cf_78' => "FDA-123",
        '*cf_77' => true,
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

    it 'syncs products requiring update with multiple hts lines' do
      @product.classifications.first.tariff_records.create! line_number: 2, hts_1: "9876543210"

      @api_client.should_receive(:find_by_uid).with("RHEE-" + @product.unique_identifier,["prod_uid", "*cf_43", "*cf_78", "*cf_77", "class_cntry_iso", "hts_line_number", "hts_hts_1", "prod_imp_syscode"]).and_return({'product'=>nil})

      # Capture and analyze the remote data later
      remote_data = nil
      @api_client.should_receive(:create) do |data|
        remote_data = data
        nil
      end

      @c.sync

      # Validate the remote data
      expect(remote_data).to eq ({ 'product' => {
        'prod_uid' => "RHEE-#{@product.unique_identifier}",
        'prod_imp_syscode' => "RHEE",
        '*cf_43' => @product.unique_identifier,
        '*cf_78' => "FDA-123",
        '*cf_77' => true,
        'classifications' => [{
          'class_cntry_iso' => @product.classifications.first.country.iso_code,
          'tariff_records' => [{
            'hts_line_number' => 1,
            'hts_hts_1' => @product.classifications.first.tariff_records.first.hts_1.hts_format
          },
          {
            'hts_line_number' => 2,
            'hts_hts_1' => @product.classifications.first.tariff_records.second.hts_1.hts_format
          },
          ]
        }]
      }})
    end

    it "syncs data the already exists in vfitrack without a classification" do
      existing_product = {'id' => 1, 'prod_uid' => "RHEE-#{@product.unique_identifier}"}
      @api_client.should_receive(:find_by_uid).with("RHEE-" + @product.unique_identifier, ["prod_uid", "*cf_43", "*cf_78", "*cf_77", "class_cntry_iso", "hts_line_number", "hts_hts_1", "prod_imp_syscode"]).and_return({'product'=>existing_product})

      remote_data = nil
      @api_client.should_receive(:update) do |data|
        remote_data = data
        nil
      end

      @c.sync

      # Validate the remote data
      expect(remote_data).to eq ({ 'product' => {
        'id' => 1,
        'prod_uid' => "RHEE-#{@product.unique_identifier}",
        'prod_imp_syscode' => "RHEE",
        '*cf_43' => @product.unique_identifier,
        '*cf_78' => "FDA-123",
        '*cf_77' => true,
        'classifications' => [{
          'class_cntry_iso' => @product.classifications.first.country.iso_code,
          'tariff_records' => [{
            'hts_line_number' => 1,
            'hts_hts_1' => @product.classifications.first.tariff_records.first.hts_1.hts_format
          }]
        }]
      }})
    end

    it "syncs data the already exists in vfitrack with a classification" do
      existing_product = {
        'id' => 1, 
        'prod_uid' => "RHEE-#{@product.unique_identifier}",
        'classifications' => [{
          'id' => 2,
          'class_cntry_iso' => "US"
        }]
      }
      @api_client.should_receive(:find_by_uid).with("RHEE-" + @product.unique_identifier, ["prod_uid", "*cf_43", "*cf_78", "*cf_77", "class_cntry_iso", "hts_line_number", "hts_hts_1", "prod_imp_syscode"]).and_return({'product'=>existing_product})

      remote_data = nil
      @api_client.should_receive(:update) do |data|
        remote_data = data
        nil
      end

      @c.sync

      # Validate the remote data
      expect(remote_data).to eq ({ 'product' => {
        'id' => 1,
        'prod_uid' => "RHEE-#{@product.unique_identifier}",
        'prod_imp_syscode' => "RHEE",
        '*cf_43' => @product.unique_identifier,
        '*cf_78' => "FDA-123",
        '*cf_77' => true,
        'classifications' => [{
          'id' => 2,
          'class_cntry_iso' => @product.classifications.first.country.iso_code,
          'tariff_records' => [{
            'hts_line_number' => 1,
            'hts_hts_1' => @product.classifications.first.tariff_records.first.hts_1.hts_format
          }]
        }]
      }})
    end

    it "syncs data the already exists in vfitrack with a tariff_record" do
      existing_product = {
        'id' => 1, 
        'prod_uid' => "RHEE-#{@product.unique_identifier}",
        'classifications' => [{
          'id' => 2,
          'class_cntry_iso' => "US",
          'tariff_records' => [{
            'id' => 3,
            'hts_line_number' => 1
          }]
        }]
      }
      @api_client.should_receive(:find_by_uid).with("RHEE-" + @product.unique_identifier, ["prod_uid", "*cf_43", "*cf_78", "*cf_77", "class_cntry_iso", "hts_line_number", "hts_hts_1", "prod_imp_syscode"]).and_return({'product'=>existing_product})

      remote_data = nil
      @api_client.should_receive(:update) do |data|
        remote_data = data
        nil
      end

      @c.sync

      # Validate the remote data
      expect(remote_data).to eq ({ 'product' => {
        'id' => 1,
        'prod_uid' => "RHEE-#{@product.unique_identifier}",
        'prod_imp_syscode' => "RHEE",
        '*cf_43' => @product.unique_identifier,
        '*cf_78' => "FDA-123",
        '*cf_77' => true,
        'classifications' => [{
          'id' => 2,
          'class_cntry_iso' => @product.classifications.first.country.iso_code,
          'tariff_records' => [{
            'id' => 3,
            'hts_line_number' => 1,
            'hts_hts_1' => @product.classifications.first.tariff_records.first.hts_1.hts_format
          }]
        }]
      }})
    end

    it "destroys tariff records in VFI Track that don't exist locally" do
      existing_product = {
        'id' => 1, 
        'prod_uid' => "RHEE-#{@product.unique_identifier}",
        'classifications' => [{
          'id' => 2,
          'class_cntry_iso' => "US",
          'tariff_records' => [{
            'id' => 3,
            'hts_line_number' => 2
          }]
        }]
      }
      @api_client.should_receive(:find_by_uid).with("RHEE-" + @product.unique_identifier, ["prod_uid", "*cf_43", "*cf_78", "*cf_77", "class_cntry_iso", "hts_line_number", "hts_hts_1", "prod_imp_syscode"]).and_return({'product'=>existing_product})

      remote_data = nil
      @api_client.should_receive(:update) do |data|
        remote_data = data
        nil
      end

      @c.sync

      # Validate the remote data
      expect(remote_data).to eq ({ 'product' => {
        'id' => 1,
        'prod_uid' => "RHEE-#{@product.unique_identifier}",
        'prod_imp_syscode' => "RHEE",
        '*cf_43' => @product.unique_identifier,
        '*cf_78' => "FDA-123",
        '*cf_77' => true,
        'classifications' => [{
          'id' => 2,
          'class_cntry_iso' => @product.classifications.first.country.iso_code,
          'tariff_records' => [{
            'id' => 3,
            'hts_line_number' => 2,
            '_destroy' => true
          },
          {
            'hts_line_number' => 1,
            'hts_hts_1' => @product.classifications.first.tariff_records.first.hts_1.hts_format
          }
          ]
        }]
      }})
    end

    it "ignores classifications for countries other than those listed locally" do
      existing_product = {
        'id' => 1, 
        'prod_uid' => "RHEE-#{@product.unique_identifier}",
        'classifications' => [{
          'id' => 2,
          'class_cntry_iso' => "CA",
          'tariff_records' => [{
            'id' => 3,
            'hts_line_number' => 1
          }]
        }]
      }
      @api_client.should_receive(:find_by_uid).with("RHEE-" + @product.unique_identifier, ["prod_uid", "*cf_43", "*cf_78", "*cf_77", "class_cntry_iso", "hts_line_number", "hts_hts_1", "prod_imp_syscode"]).and_return({'product'=>existing_product})

      remote_data = nil
      @api_client.should_receive(:update) do |data|
        remote_data = data
        nil
      end

      @c.sync

      # Validate the remote data
      expect(remote_data).to eq ({ 'product' => {
        'id' => 1,
        'prod_uid' => "RHEE-#{@product.unique_identifier}",
        'prod_imp_syscode' => "RHEE",
        '*cf_43' => @product.unique_identifier,
        '*cf_78' => "FDA-123",
        '*cf_77' => true,
        'classifications' => [{
          'id' => 2,
          'class_cntry_iso' => "CA",
          'tariff_records' => [{
            'id' => 3,
            'hts_line_number' => 1
          }]
        },
        {
          'class_cntry_iso' => "US",
          'tariff_records' => [{
            'hts_line_number' => 1,
            'hts_hts_1' => @product.classifications.first.tariff_records.first.hts_1.hts_format
          }]
        }
        ]
      }})
    end
  end
end