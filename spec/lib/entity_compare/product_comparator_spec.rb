require 'spec_helper'

describe OpenChain::EntityCompare::ProductComparator do
  let(:klass) do
    Class.new { extend OpenChain::EntityCompare::ProductComparator }
  end

  describe "get_hts" do
    let!(:cl_hsh) do
      {"entity"=>{"core_module"=>"Classification", 
                  "model_fields"=>{"class_cntry_iso"=>"US"}, 
                  "children"=>[{"entity"=>{"core_module"=>"TariffRecord", 
                                           "model_fields"=>{"hts_hts_1"=>"1111.11.1111"}}}]}}
    end

    it "retrieves tariff number from classification hash" do
      expect(klass.get_hts(cl_hsh)).to eq "1111.11.1111"
    end

    it "returns nil if the hts field is missing" do
      cl_hsh["entity"]["children"][0]["entity"]["model_fields"].delete("hts_hts_1")
      expect(klass.get_hts(cl_hsh)).to be_nil
    end

    it "returns nil if the tariff record is missing" do
      cl_hsh["entity"]["children"].delete_at(0)
      expect(klass.get_hts(cl_hsh)).to be_nil
    end
  end
end
