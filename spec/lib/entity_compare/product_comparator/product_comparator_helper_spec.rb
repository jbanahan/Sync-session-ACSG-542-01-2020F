describe OpenChain::EntityCompare::ProductComparator::ProductComparatorHelper do
  subject do
    Class.new { extend OpenChain::EntityCompare::ProductComparator::ProductComparatorHelper }
  end

  describe "get_hts" do
    let!(:cl_hsh) do
      {"entity"=>{"core_module"=>"Classification",
                  "model_fields"=>{"class_cntry_iso"=>"US"},
                  "children"=>[{"entity"=>{"core_module"=>"TariffRecord",
                                           "model_fields"=>{"hts_hts_1"=>"1111.11.1111"}}}]}}
    end

    it "retrieves tariff number from classification hash" do
      expect(subject.get_hts(cl_hsh)).to eq "1111111111"
    end

    it "returns nil if the hts field is missing" do
      cl_hsh["entity"]["children"][0]["entity"]["model_fields"].delete("hts_hts_1")
      expect(subject.get_hts(cl_hsh)).to be_nil
    end

    it "returns nil if the tariff record is missing" do
      cl_hsh["entity"]["children"].delete_at(0)
      expect(subject.get_hts(cl_hsh)).to be_nil
    end
  end


  describe "get_all_hts" do
    let (:classification_snapshot) {
      {"entity"=>{"core_module"=>"Classification",
                  "model_fields"=>{"class_cntry_iso"=>"US"},
                  "children"=>[{"entity"=>{"core_module"=>"TariffRecord",
                                           "model_fields"=>{"hts_hts_1"=>"1111.11.1111"}}},

                                {"entity"=>{"core_module"=>"TariffRecord",
                                           "model_fields"=>{"hts_hts_1"=>"2222.22.2222"}}}
                              ]

                  }
      }
    }

    it "returns all hts values - sans periods" do
      expect(subject.get_all_hts(classification_snapshot)).to eq ["1111111111", "2222222222"]
    end

    it "skips blank values" do
      classification_snapshot["entity"]["children"].first["entity"]["model_fields"]["hts_hts_1"] = "   "
      expect(subject.get_all_hts(classification_snapshot)).to eq ["2222222222"]
    end

    it "returns blank array if no tariffs are found" do
      classification_snapshot["entity"]["children"] = []
      expect(subject.get_all_hts(classification_snapshot)).to eq []
    end
  end

  describe "get_country_tariffs" do
    let (:classification_snapshot) {
      {
        "entity" => {
          "core_module" => "",
          "children" => [
            {
              "entity"=>{
                "core_module"=>"Classification",
                "model_fields"=> {
                  "class_cntry_iso"=>"US"
                },
                "children"=> [
                  {
                    "entity"=>{
                      "core_module"=>"TariffRecord",
                      "model_fields"=>{"hts_hts_1"=>"1111.11.1111"}
                    }
                  },
                  {
                    "entity"=>{
                      "core_module"=>"TariffRecord",
                      "model_fields"=>{
                        "hts_hts_1"=>"2222.22.2222"
                      }
                    }
                  }
                ]
              }
            }
          ]
        }
      }
    }

    it "returns all classifications for a specific country" do
      expect(subject.get_country_tariffs(classification_snapshot, "US")).to eq ["1111111111", "2222222222"]
    end

    it "retuns blank array for non-existent country" do
      expect(subject.get_country_tariffs(classification_snapshot, "CA")).to eq []
    end
  end
end