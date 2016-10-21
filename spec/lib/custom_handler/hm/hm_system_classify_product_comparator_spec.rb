require 'spec_helper'

describe OpenChain::CustomHandler::Hm::HmSystemClassifyProductComparator do
  let(:cdef) { described_class.prep_custom_definitions([:prod_system_classified])[:prod_system_classified] }
  let(:u) { Factory(:user, username: "integration") }
  let!(:company) { Factory(:company, alliance_customer_number: "HENNE")}
  let!(:country_ca) { Factory(:country, iso_code: "CA")}
  let!(:country_us) { Factory(:country, iso_code: "US")}

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
    let!(:dcr) { DataCrossReference.create_hm_us_hts_to_ca! "1111111111", "3333333333" }
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

  describe "get_hts" do
    let!(:cl_hsh) do
      {"entity"=>{"core_module"=>"Classification", 
                  "model_fields"=>{"class_cntry_iso"=>"US"}, 
                  "children"=>[{"entity"=>{"core_module"=>"TariffRecord", 
                                           "model_fields"=>{"hts_hts_1"=>"1111.11.1111"}}}]}}
    end

    it "retrieves tariff number from classification hash" do
      expect(described_class.get_hts(cl_hsh)).to eq "1111.11.1111"
    end

    it "returns nil if the hts field is missing" do
      cl_hsh["entity"]["children"][0]["entity"]["model_fields"].delete("hts_hts_1")
      expect(described_class.get_hts(cl_hsh)).to be_nil
    end

    it "returns nil if the tariff record is missing" do
      cl_hsh["entity"]["children"].delete_at(0)
      expect(described_class.get_hts(cl_hsh)).to be_nil
    end
  end

  describe "update_product!" do   
    it "sets CA tariff number, sets flag, saves entity snapshot" do
      tariff = Factory(:tariff_record, classification: Factory(:classification, country: country_ca))
      prod = tariff.classification.product
      prod.update_custom_value!(cdef, nil)
      expect_any_instance_of(Product).to receive(:create_snapshot).with(User.integration, nil, "HmSystemClassifyProductComparator")
      
      described_class.update_product! prod.id, "2222222222"
      
      prod.reload; tariff.reload
      expect(tariff.hts_1).to eq "2222222222"
      expect(prod.get_custom_value(cdef).value).to eq true
    end

    it "does nothing if CA tariff number already exists" do
      tariff = Factory(:tariff_record, classification: Factory(:classification, country: country_ca), hts_1: "4444444444" )
      prod = tariff.classification.product
      expect_any_instance_of(Product).not_to receive(:create_snapshot)
      
      described_class.update_product! prod.id, "2222222222"
      
      tariff.reload
      expect(tariff.hts_1).to eq "4444444444"
    end
  end
end