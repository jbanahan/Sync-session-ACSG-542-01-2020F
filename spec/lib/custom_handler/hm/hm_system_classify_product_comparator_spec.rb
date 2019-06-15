describe OpenChain::CustomHandler::Hm::HmSystemClassifyProductComparator do
  let(:u) { Factory(:user, username: "integration") }
  let!(:company) { Factory(:company, system_code: "HENNE")}
  let!(:country_ca) { Factory(:country, iso_code: "CA")}
  let!(:country_us) { Factory(:country, iso_code: "US")}

  describe "accept?" do
    let!(:prod) { Factory(:product, importer: company) }
    let(:snap) { Factory(:entity_snapshot, recordable: prod) }

    it "returns true if snapshot belongs to an H&M product" do
      expect(described_class.accept?(snap)).to be true
    end

    it "returns false if the product isn't H&M" do
      company.update_attributes(system_code: "ACME")
      expect(described_class.accept?(snap)).to be false
    end
    
    it "returns false if the snapshot doesn't belong to a product" do
      snap.update_attributes(recordable: Factory(:entry))
      expect(described_class.accept?(snap)).to be false
    end
  end

  describe "compare" do
    it "exits if the type isn't a product" do
      expect(described_class).to_not receive(:get_json_hash)
      expect(described_class).to_not receive(:check_classification)
      described_class.compare("Entry", 1, "old_bucket", "old_path", "old_version", "new_bucket", "new_path", "new_version")
    end

    it "exits if the product doesn't belong to H&M" do
      prod_hsh = {"entity"=>{"core_module"=>"Product", "record_id"=>1, "model_fields"=>{"prod_imp_syscode"=>"ACME"}}}
      expect(described_class).to receive(:get_json_hash).and_return prod_hsh
      expect(described_class).to_not receive(:check_classification)
      described_class.compare("Product", 1, "old_bucket", "old_path", "old_version", "new_bucket", "new_path", "new_version")
    end

    it "runs comparison" do
      prod_hsh = {"entity"=>{"core_module"=>"Product", "record_id"=>1, "model_fields"=>{"prod_imp_syscode"=>"HENNE"}}}
      expect(described_class).to receive(:get_json_hash).and_return prod_hsh
      expect(described_class).to receive(:check_classification).with(prod_hsh)
      described_class.compare("Product", 1, "old_bucket", "old_path", "old_version", "new_bucket", "new_path", "new_version")
    end
  end

  describe "check_classification" do
    let!(:dcr) { DataCrossReference.create_us_hts_to_ca! "1111111111", "3333333333", company.id}
    let!(:prod_hsh) do
      {"entity"=>{"core_module"=>"Product", 
                  "record_id"=>1, 
                  "model_fields"=>{"prod_imp_syscode"=>"HENNE"}, 
                  "children"=>[{"entity"=>{"core_module"=>"Classification", 
                                           "model_fields"=>{"class_cntry_iso"=>"US"}, 
                                           "children"=>[{"entity"=>{"core_module"=>"TariffRecord", 
                                                                   "model_fields"=>{"hts_hts_1"=>"1111.11.1111"}}}]}}, 
                               {"entity"=>{"core_module"=>"Classification", 
                                           "model_fields"=>{"class_cntry_iso"=>"CA"}, 
                                           "children"=>[{"entity"=>{"core_module"=>"TariffRecord", 
                                                                    "model_fields"=>{"hts_hts_1"=>"2222.22.2222"}}}]}}]}}
    end

    context "with CA classification, tariff, hts_1" do
      it "skips product if CA tariff number is already populated" do 
        expect(described_class).not_to receive(:update_product!)
        described_class.check_classification prod_hsh
      end
    end

    context "without CA classification" do
      it "skips product if US tariff number isn't on cross-ref list" do
        #delete CA classification
        prod_hsh["entity"]["children"].delete_at(1)
        
        #reassign US HTS number
        prod_hsh["entity"]["children"][0]["entity"]["children"][0]["entity"]["model_fields"]["hts_hts_1"] = "1234.56.7890"
        
        expect(described_class).not_to receive(:update_product!)
        described_class.check_classification prod_hsh
      end
      
      it "updates product if US tariff number is on cross-ref list" do
        #delete CA classification
        prod_hsh["entity"]["children"].delete_at(1)
        expect(described_class).to receive(:update_product!).with(1, "3333333333")
        described_class.check_classification prod_hsh
      end
    end
  end

  describe "update_product!" do   
    let!(:cdefs) { described_class.prep_custom_definitions([:prod_system_classified, :class_customs_description])}
    let(:flag_cdef) { cdefs[:prod_system_classified] }
    before { DataCrossReference.create_ca_hts_to_descr! "3333333333", "cement shoes", company.id }

    it "sets CA tariff number, flag, customs description; saves entity snapshot" do
      descr_cdef = cdefs[:class_customs_description]
      tariff = Factory(:tariff_record, classification: Factory(:classification, country: country_ca, product: Factory(:product, importer: company)))
      classi = tariff.classification
      prod = classi.product
      prod.assign_attributes(importer: company)
      prod.find_and_set_custom_value(flag_cdef, nil)
      prod.save!
      expect(described_class).to receive(:update_classi!).with(classi, descr_cdef, "3333333333", prod.importer_id)
      expect_any_instance_of(Product).to receive(:create_snapshot).with(User.integration, nil, "HmSystemClassifyProductComparator")
      
      described_class.update_product! prod.id, "3333333333"
      
      prod.reload; tariff.reload; classi.reload
      expect(tariff.hts_1).to eq "3333333333"
      expect(prod.get_custom_value(flag_cdef).value).to eq true
    end

    it "does nothing if CA tariff number already exists" do
      tariff = Factory(:tariff_record, classification: Factory(:classification, country: country_ca), hts_1: "4444444444" )
      classi = tariff.classification
      prod = classi.product
      prod.assign_attributes(importer: company)
      prod.find_and_set_custom_value(flag_cdef, nil)
      prod.save!
      expect(described_class).not_to receive(:update_classi!)
      expect_any_instance_of(Product).not_to receive(:create_snapshot)
      
      described_class.update_product! prod.id, "3333333333"
      
      prod.reload; tariff.reload; classi.reload
      expect(tariff.hts_1).to eq "4444444444"
      expect(prod.get_custom_value(flag_cdef).value).to be_nil
    end
  end

  describe "update_classi!" do
    let(:classi) { Factory(:classification, country: country_ca, product: Factory(:product, importer: company)) }
    let!(:cdef) { described_class.prep_custom_definitions([:class_customs_description])[:class_customs_description]}
    before { DataCrossReference.create_ca_hts_to_descr! "3333333333", "cement shoes", company.id }

    it "updates customs description if it's blank" do
      classi.update_custom_value!(cdef, nil)
      described_class.update_classi!(classi, cdef, "3333333333", classi.product.importer_id)
      classi.reload
      expect(classi.custom_value(cdef)).to eq "cement shoes"
    end

    it "leaves customs description unchanged if it isn't blank" do
      classi.update_custom_value!(cdef, "Davy Jones's locker")
      described_class.update_classi!(classi, cdef, "3333333333", classi.product.importer_id)
      classi.reload
      expect(classi.custom_value(cdef)).to eq "Davy Jones's locker"
    end
  end
end