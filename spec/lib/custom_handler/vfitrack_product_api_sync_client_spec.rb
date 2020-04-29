describe OpenChain::CustomHandler::VfiTrackProductApiSyncClient do

  describe "sync" do
    let (:api_client) { instance_double(OpenChain::Api::ProductApiClient) }
    let (:importer) { Factory(:importer, system_code: "SYSCODE")}
    let! (:product) {
      product = Factory(:product, importer: importer, unique_identifier: "UID", name: "NAME")
      product.update_custom_value! cdefs[:prod_fda_product_code], "FDA-123"
      product.update_custom_value! cdefs[:prod_country_of_origin], "CN"

      classification = Factory(:classification, product: product, country: Factory(:country, iso_code: "US"))
      classification.update_custom_value! cdefs[:class_customs_description], "Description"

      tariff = Factory(:tariff_record, hts_1: "1234567890", hts_2: "0987654321", hts_3: "2468101214", classification: classification)
      product.reload
    }

    let (:cdefs) {
      subject.cdefs
    }

    subject {
      Class.new(OpenChain::CustomHandler::VfiTrackProductApiSyncClient) {
        include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

        attr_reader :cdefs

        def initialize
          super(api_client: true)
          @cdefs = self.class.prep_custom_definitions [:prod_country_of_origin, :class_customs_description, :prod_fda_product_code]
        end

        def query_row_map
          [:product_id, :prod_uid, :prod_name, :prod_country_of_origin, :fda_product_code, :class_cntry_iso, :class_customs_description, :hts_line_number, :hts_hts_1, :hts_hts_2, :hts_hts_3]
        end

        def query
          <<-SQL
            SELECT products.id, products.unique_identifier, products.name, coo.string_value, fda.string_value, country.iso_code, cd.string_value, t.line_number, t.hts_1, t.hts_2, t.hts_3
            FROM products products
              INNER JOIN custom_values coo ON products.id = coo.customizable_id AND coo.customizable_type = 'Product' and coo.custom_definition_id = #{@cdefs[:prod_country_of_origin].id}
              INNER JOIN custom_values fda ON products.id = fda.customizable_id AND fda.customizable_type = 'Product' and fda.custom_definition_id = #{@cdefs[:prod_fda_product_code].id}
              INNER JOIN classifications c ON products.id = c.product_id
              INNER JOIN custom_values cd ON c.id = cd.customizable_id AND cd.customizable_type = 'Classification' and cd.custom_definition_id = #{@cdefs[:class_customs_description].id}
              INNER JOIN countries country on c.country_id = country.id
              INNER JOIN tariff_records t on t.classification_id = c.id
              #{Product.need_sync_join_clause("vfitrack")}
            WHERE #{Product.need_sync_where_clause}
          SQL
        end

        def vfitrack_importer_syscode var
          "SYSCODE"
        end

      }.new
    }

    before :each do
      allow(subject).to receive(:api_client).and_return api_client
    end

    it "syncs product requiring update to a remote VFI Track instance not having that product data" do
      # We're going to mock out the data for the remote calls
      expect(api_client).to receive(:find_by_uid).with("SYSCODE-" + product.unique_identifier, ["prod_uid", "*cf_43", "prod_name", "*cf_41", "*cf_78", "*cf_77", "class_cntry_iso", "*cf_99", "hts_line_number", "hts_hts_1", "hts_hts_2", "hts_hts_3", "prod_imp_syscode"]).and_return({'product'=>nil})

      # Capture and analyze the remote data later
      remote_data = nil
      expect(api_client).to receive(:create) do |data|
        remote_data = data
        nil
      end

      subject.sync

      # Validate the remote data
      expect(remote_data).to eq ({ 'product' => {
        'prod_uid' => "SYSCODE-UID",
        'prod_imp_syscode' => "SYSCODE",
        '*cf_43' => "UID",
        '*cf_78' => "FDA-123",
        '*cf_77' => true,
        "prod_name" => "NAME",
        "*cf_41" => "CN",
        'classifications' => [{
          'class_cntry_iso' => "US",
          '*cf_99' => "Description",
          'tariff_records' => [{
            'hts_line_number' => 1,
            'hts_hts_1' => "1234.56.7890",
            'hts_hts_2' => "0987.65.4321",
            'hts_hts_3' => "2468.10.1214"
          }]
        }]
      }})

      sr = product.reload.sync_records.first
      expect(sr).not_to be_nil
      # Just validate the trading partner, every other aspect of the sync record data is the responsibility
      # of the parent class of the one we're testing
      expect(sr.trading_partner).to eq "vfitrack"
    end

    it 'syncs products requiring update with multiple hts lines' do
      product.classifications.first.tariff_records.create! line_number: 2, hts_1: "9876543210"

      expect(api_client).to receive(:find_by_uid).with("SYSCODE-" + product.unique_identifier, ["prod_uid", "*cf_43", "prod_name", "*cf_41", "*cf_78", "*cf_77", "class_cntry_iso", "*cf_99", "hts_line_number", "hts_hts_1", "hts_hts_2", "hts_hts_3", "prod_imp_syscode"]).and_return({'product'=>nil})

      # Capture and analyze the remote data later
      remote_data = nil
      expect(api_client).to receive(:create) do |data|
        remote_data = data
        nil
      end

      subject.sync

      expect(remote_data).to eq ({ 'product' => {
        'prod_uid' => "SYSCODE-UID",
        'prod_imp_syscode' => "SYSCODE",
        '*cf_43' => "UID",
        '*cf_78' => "FDA-123",
        '*cf_77' => true,
        "prod_name" => "NAME",
        "*cf_41" => "CN",
        'classifications' => [{
          'class_cntry_iso' => "US",
          '*cf_99' => "Description",
          'tariff_records' => [{
            'hts_line_number' => 1,
            'hts_hts_1' => "1234.56.7890",
            'hts_hts_2' => "0987.65.4321",
            'hts_hts_3' => "2468.10.1214"
          },
          {
            'hts_line_number' => 2,
            "hts_hts_1" => "9876.54.3210",
            'hts_hts_2' => nil,
            'hts_hts_3' => nil
          }
          ]
        }]
      }})
    end

    it "syncs data the already exists in vfitrack without a classification" do
      existing_product = {'id' => 1, 'prod_uid' => "SYSCODE-UID"}
      expect(api_client).to receive(:find_by_uid).with("SYSCODE-" + product.unique_identifier, ["prod_uid", "*cf_43", "prod_name", "*cf_41", "*cf_78", "*cf_77", "class_cntry_iso", "*cf_99", "hts_line_number", "hts_hts_1", "hts_hts_2", "hts_hts_3", "prod_imp_syscode"]).and_return({'product'=>existing_product})

      remote_data = nil
      expect(api_client).to receive(:update) do |data|
        remote_data = data
        nil
      end

      subject.sync

      expect(remote_data).to eq ({ 'product' => {
        "id" => 1,
        'prod_uid' => "SYSCODE-UID",
        'prod_imp_syscode' => "SYSCODE",
        '*cf_43' => "UID",
        '*cf_78' => "FDA-123",
        '*cf_77' => true,
        "prod_name" => "NAME",
        "*cf_41" => "CN",
        'classifications' => [{
          'class_cntry_iso' => "US",
          '*cf_99' => "Description",
          'tariff_records' => [{
            'hts_line_number' => 1,
            'hts_hts_1' => "1234.56.7890",
            'hts_hts_2' => "0987.65.4321",
            'hts_hts_3' => "2468.10.1214"
          }]
        }]
      }})
    end

    it "syncs data the already exists in vfitrack with a classification" do
      existing_product = {
        'id' => 1,
        'prod_uid' => "SYSCODE-UID",
        'classifications' => [{
          'id' => 2,
          'class_cntry_iso' => "US"
        }]
      }
      expect(api_client).to receive(:find_by_uid).with("SYSCODE-" + product.unique_identifier, ["prod_uid", "*cf_43", "prod_name", "*cf_41", "*cf_78", "*cf_77", "class_cntry_iso", "*cf_99", "hts_line_number", "hts_hts_1", "hts_hts_2", "hts_hts_3", "prod_imp_syscode"]).and_return({'product'=>existing_product})

      remote_data = nil
      expect(api_client).to receive(:update) do |data|
        remote_data = data
        nil
      end

      subject.sync

      expect(remote_data).to eq ({ 'product' => {
        "id" => 1,
        'prod_uid' => "SYSCODE-UID",
        'prod_imp_syscode' => "SYSCODE",
        '*cf_43' => "UID",
        '*cf_78' => "FDA-123",
        '*cf_77' => true,
        "prod_name" => "NAME",
        "*cf_41" => "CN",
        'classifications' => [{
          'id' => 2,
          'class_cntry_iso' => "US",
          '*cf_99' => "Description",
          'tariff_records' => [{
            'hts_line_number' => 1,
            'hts_hts_1' => "1234.56.7890",
            'hts_hts_2' => "0987.65.4321",
            'hts_hts_3' => "2468.10.1214"
          }]
        }]
      }})
    end

    it "syncs data the already exists in vfitrack with a tariff_record" do
      existing_product = {
        'id' => 1,
        'prod_uid' => "SYSCODE-UID",
        'classifications' => [{
          'id' => 2,
          'class_cntry_iso' => "US",
          'tariff_records' => [{
            'id' => 3,
            'hts_line_number' => 1
          }]
        }]
      }
      expect(api_client).to receive(:find_by_uid).with("SYSCODE-" + product.unique_identifier, ["prod_uid", "*cf_43", "prod_name", "*cf_41", "*cf_78", "*cf_77", "class_cntry_iso", "*cf_99", "hts_line_number", "hts_hts_1", "hts_hts_2", "hts_hts_3", "prod_imp_syscode"]).and_return({'product'=>existing_product})

      remote_data = nil
      expect(api_client).to receive(:update) do |data|
        remote_data = data
        nil
      end

      subject.sync

      expect(remote_data).to eq ({ 'product' => {
        "id" => 1,
        'prod_uid' => "SYSCODE-UID",
        'prod_imp_syscode' => "SYSCODE",
        '*cf_43' => "UID",
        '*cf_78' => "FDA-123",
        '*cf_77' => true,
        "prod_name" => "NAME",
        "*cf_41" => "CN",
        'classifications' => [{
          'id' => 2,
          'class_cntry_iso' => "US",
          '*cf_99' => "Description",
          'tariff_records' => [{
            'id' => 3,
            'hts_line_number' => 1,
            'hts_hts_1' => "1234.56.7890",
            'hts_hts_2' => "0987.65.4321",
            'hts_hts_3' => "2468.10.1214"
          }]
        }]
      }})
    end

    it "destroys tariff records in VFI Track that don't exist locally" do
      existing_product = {
        'id' => 1,
        'prod_uid' => "SYSCODE-UID",
        'classifications' => [{
          'id' => 2,
          'class_cntry_iso' => "US",
          'tariff_records' => [{
            'id' => 3,
            'hts_line_number' => 2
          }]
        }]
      }
      expect(api_client).to receive(:find_by_uid).with("SYSCODE-" + product.unique_identifier, ["prod_uid", "*cf_43", "prod_name", "*cf_41", "*cf_78", "*cf_77", "class_cntry_iso", "*cf_99", "hts_line_number", "hts_hts_1", "hts_hts_2", "hts_hts_3", "prod_imp_syscode"]).and_return({'product'=>existing_product})

      remote_data = nil
      expect(api_client).to receive(:update) do |data|
        remote_data = data
        nil
      end

      subject.sync

      expect(remote_data).to eq ({ 'product' => {
        "id" => 1,
        'prod_uid' => "SYSCODE-UID",
        'prod_imp_syscode' => "SYSCODE",
        '*cf_43' => "UID",
        '*cf_78' => "FDA-123",
        '*cf_77' => true,
        "prod_name" => "NAME",
        "*cf_41" => "CN",
        'classifications' => [{
          'id' => 2,
          'class_cntry_iso' => "US",
          '*cf_99' => "Description",
          'tariff_records' => [{
            'id' => 3,
            'hts_line_number' => 2,
            '_destroy' => true
            }, {
            'hts_line_number' => 1,
            'hts_hts_1' => "1234.56.7890",
            'hts_hts_2' => "0987.65.4321",
            'hts_hts_3' => "2468.10.1214"
          }]
        }]
      }})
    end

    it "ignores classifications for countries other than those listed locally" do

      existing_product = {
        'id' => 1,
        'prod_uid' => "SYSCODE-UID",
        'classifications' => [{
          'id' => 2,
          'class_cntry_iso' => "CA",
          'tariff_records' => [{
            'id' => 3,
            'hts_line_number' => 1
          }]
        }]
      }
      expect(api_client).to receive(:find_by_uid).with("SYSCODE-" + product.unique_identifier, ["prod_uid", "*cf_43", "prod_name", "*cf_41", "*cf_78", "*cf_77", "class_cntry_iso", "*cf_99", "hts_line_number", "hts_hts_1", "hts_hts_2", "hts_hts_3", "prod_imp_syscode"]).and_return({'product'=>existing_product})

      remote_data = nil
      expect(api_client).to receive(:update) do |data|
        remote_data = data
        nil
      end

      subject.sync

      expect(remote_data).to eq ({ 'product' => {
        "id" => 1,
        'prod_uid' => "SYSCODE-UID",
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
          '*cf_99' => "Description",
          'tariff_records' => [{
            'hts_line_number' => 1,
            'hts_hts_1' => "1234.56.7890",
            'hts_hts_2' => "0987.65.4321",
            'hts_hts_3' => "2468.10.1214"
          }]
        }],
        'prod_imp_syscode' => "SYSCODE",
        '*cf_43' => "UID",
        '*cf_78' => "FDA-123",
        '*cf_77' => true,
        "prod_name" => "NAME",
        "*cf_41" => "CN",
      }})
    end
  end
end
