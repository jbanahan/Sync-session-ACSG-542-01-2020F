describe OpenChain::CustomHandler::Polo::PoloFdaProductComparator do
  let(:cdef) { described_class.prep_custom_definitions([:prod_fda_indicator])[:prod_fda_indicator] }
  let(:old_hsh) do
    {"entity"=>{"core_module" => "Product",
                "model_fields" => {"*cf_#{cdef.id}" => ""},
                "children" => [{"entity" => {"core_module" => "Classification",
                                            "model_fields" => {"class_cntry_iso"=>"US"},
                                            "children" => [{"entity" => {"core_module" => "TariffRecord",
                                                                         "model_fields" => {"hts_hts_1" => "1234.56.7890"}}},
                                                           {"entity" => {"core_module" => "TariffRecord",
                                                                         "model_fields" => {"hts_hts_1" => "0987.65.4321"}}}]}}]}}
  end

  def copy_hsh h
    Marshal.load(Marshal.dump(h))
  end

  def assign_first_hts hsh, hts
    hsh["entity"]["children"].first["entity"]["children"].first["entity"]["model_fields"]["hts_hts_1"] = hts
  end

  describe "compare" do
    let(:prod) { Factory(:product) }

    it "does nothing if type isn't product" do
      expect(described_class).not_to receive(:get_country_tariffs)
      described_class.compare('Entry', 1, 'old_bucket', 'old_path', 'old_version', 'new_bucket', 'new_path', 'new_version')
    end

    it "does nothing if old and new snapshots have same US tariffs" do
      new_hsh = copy_hsh old_hsh
      expect(described_class).to receive(:get_json_hash).with('old_bucket', 'old_path', 'old_version').and_return old_hsh
      expect(described_class).to receive(:get_json_hash).with('new_bucket', 'new_path', 'new_version').and_return new_hsh
      expect(described_class).to_not receive(:fda_indicator_from_product)
      described_class.compare('Product', 1, 'old_bucket', 'old_path', 'old_version', 'new_bucket', 'new_path', 'new_version')
    end

    it "does nothing if new snapshot has HTS associated with the same FDA indicator value" do
      new_hsh = copy_hsh old_hsh
      assign_first_hts new_hsh, "2468.10.1214"
      old_hsh["entity"]["model_fields"]["*cf_#{cdef.id}"] = "FD1"
      OfficialTariff.create!(country: Factory(:country, iso_code: "US"), hts_code: "2468101214", fda_indicator: "FD1")

      expect(described_class).to receive(:get_json_hash).with('old_bucket', 'old_path', 'old_version').and_return old_hsh
      expect(described_class).to receive(:get_json_hash).with('new_bucket', 'new_path', 'new_version').and_return new_hsh
      expect(prod).to_not receive(:update_custom_value!)
      expect(prod).to_not receive(:create_snapshot)

      described_class.compare('Product', prod.id, 'old_bucket', 'old_path', 'old_version', 'new_bucket', 'new_path', 'new_version')
    end

    it "updates the product and takes a snapshot if new snapshot has HTS associated with new FDA indicator value" do
      new_hsh = copy_hsh old_hsh
      assign_first_hts new_hsh, "2468.10.1214"
      old_hsh["entity"]["model_fields"]["*cf_#{cdef.id}"] = "FD1"
      prod.update_custom_value!(cdef, "FD1")
      OfficialTariff.create!(country: Factory(:country, iso_code: "US"), hts_code: "2468101214", fda_indicator: "FD2")

      expect(described_class).to receive(:get_json_hash).with('old_bucket', 'old_path', 'old_version').and_return old_hsh
      expect(described_class).to receive(:get_json_hash).with('new_bucket', 'new_path', 'new_version').and_return new_hsh
      expect_any_instance_of(Product).to receive(:create_snapshot).with(User.integration, nil, "Polo FDA Comparator")

      described_class.compare('Product', prod.id, 'old_bucket', 'old_path', 'old_version', 'new_bucket', 'new_path', 'new_version')
      prod.reload
      expect(prod.custom_value(cdef)).to eq "FD2"
    end

    it "updates the product and takes a snapshot if new snapshot has no HTS associated with an FDA indicator value" do
      new_hsh = copy_hsh old_hsh
      assign_first_hts new_hsh, "2468.10.1214"
      old_hsh["entity"]["model_fields"]["*cf_#{cdef.id}"] = "FD1"
      prod.update_custom_value!(cdef, "FD1")

      expect(described_class).to receive(:get_json_hash).with('old_bucket', 'old_path', 'old_version').and_return old_hsh
      expect(described_class).to receive(:get_json_hash).with('new_bucket', 'new_path', 'new_version').and_return new_hsh
      expect_any_instance_of(Product).to receive(:create_snapshot).with(User.integration, nil, "Polo FDA Comparator")

      described_class.compare('Product', prod.id, 'old_bucket', 'old_path', 'old_version', 'new_bucket', 'new_path', 'new_version')
      prod.reload
      expect(prod.custom_value(cdef)).to be_nil
    end
  end

  describe "fda_indicator_from_product" do
    let(:united_states) { Factory(:country, iso_code: "US")}

    it "returns FDA indicator for first HTS that has one" do
      OfficialTariff.create! country: united_states, hts_code: "0987654321", fda_indicator: "FOO\n FD1"
      expect(described_class.fda_indicator_from_product old_hsh).to eq "FD1"
    end

    it "returns nil if FDA indicators don't include 'FD1' or 'FD2'" do
      OfficialTariff.create! country: united_states, hts_code: "0987654321", fda_indicator: "FOO\n BAR"
      expect(described_class.fda_indicator_from_product old_hsh).to be_nil
    end

    it "returns nil if no HTS has an FDA indicator" do
      expect(described_class.fda_indicator_from_product old_hsh).to be_nil
    end
  end

  describe "tariffs_identical?" do
    it "returns 'true' if tariff numbers on JSON are the same" do
      new_hsh = copy_hsh old_hsh
      expect(described_class.tariffs_identical? old_hsh, new_hsh).to eq true
    end

    it "returns 'false' if tariff numbers on JSON are different" do
      new_hsh = copy_hsh old_hsh
      new_hsh["entity"]["children"].first["entity"]["children"].first["entity"]["model_fields"]["hts_hts_1"] = "2468.10.1214"
      expect(described_class.tariffs_identical? old_hsh, new_hsh).to eq false
    end
  end

end