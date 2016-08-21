require 'spec_helper'

describe OpenChain::BillingComparators::ProductComparator do
  let :base_hash do
    {"entity"=>{"core_module"=>"Product", "record_id"=>1, "children"=>
                    [{"entity"=>{"core_module"=>"Classification", "record_id"=>1, "model_fields"=>{"class_cntry_iso"=>"US"}, "children" =>
                        [{"entity"=>{"core_module"=>"TariffRecord", "record_id"=>1, "model_fields"=>{"hts_line_number"=>1, "hts_hts_1"=>"1111"}}}]}}]}}
  end

  describe :compare do
    it "exits if the type isn't 'Product'" do
      expect(EntitySnapshot).not_to receive(:where)
      described_class.compare('Entry', 'id', 'old_bucket', 'old_path', 'old_version', 'new_bucket', 'new_path', 'new_version')
    end

    it "runs comparisons" do
      es = Factory(:entity_snapshot, bucket: "new_bucket", doc_path: "new_path", version: "new_version")
      
      expect(described_class).to receive(:check_new_classification).with(id: 'id', old_bucket: 'old_bucket', old_path: 'old_path', old_version: 'old_version', 
                                                                    new_bucket: 'new_bucket', new_path: 'new_path', new_version: 'new_version', new_snapshot_id: es.id)
      
      described_class.compare('Product', 'id', 'old_bucket', 'old_path', 'old_version', 'new_bucket', 'new_path', 'new_version')
    end
  end

  describe :check_new_classification do
    before(:each) do 
      @class = Factory(:classification)
      base_hash["entity"]["children"].first["entity"]["record_id"] = @class.id
      @es = Factory(:entity_snapshot)
    end

    it "creates a billable event for every classification on the product if the product is new" do
      expect(described_class).to receive(:get_json_hash).with(nil,nil,nil) {}
      expect(described_class).to receive(:get_json_hash).with('new_bucket', 'new_path', 'new_version').and_return base_hash

      described_class.check_new_classification(id: 9, old_bucket: nil, old_path: nil, old_version: nil, new_bucket: 'new_bucket', 
                                               new_path: 'new_path', new_version: 'new_version', new_snapshot_id: @es.id)

      expect(BillableEvent.count).to eq 1
      be = BillableEvent.first
      expected = [@class, @es, "classification_new"]
      expect([be.billable_eventable, be.entity_snapshot, be.event_type]).to eq expected
    end

    it "creates a billable event for every classification not on the old version of the product" do
      class_2 = Factory(:classification)
      base_hash_2 = Marshal.load(Marshal.dump base_hash) #creates deep copy -- http://stackoverflow.com/a/4157635
      new_class = [{"entity"=>{"core_module"=>"Classification", "record_id"=>class_2.id, "model_fields"=>{"class_cntry_iso"=>"CA"}, "children" =>
                     [{"entity"=>{"core_module"=>"TariffRecord", "record_id"=>2, "model_fields"=>{"hts_line_number"=>1, "hts_hts_1"=>"2222"}}}]}}]
      base_hash_2["entity"]["children"] += new_class

      expect(described_class).to receive(:get_json_hash).with('old_bucket', 'old_path', 'old_version').and_return base_hash
      expect(described_class).to receive(:get_json_hash).with('new_bucket', 'new_path', 'new_version').and_return base_hash_2

      described_class.check_new_classification(id: 9, old_bucket: 'old_bucket', old_path: 'old_path', old_version: 'old_version', 
                                               new_bucket: 'new_bucket', new_path: 'new_path', new_version: 'new_version', new_snapshot_id: @es.id)

      expect(BillableEvent.count). to eq 1
      be = BillableEvent.first
      expected = [class_2, @es, "classification_new"]
      expect([be.billable_eventable, be.entity_snapshot, be.event_type]).to eq expected
    end
  end

  describe :get_classifications do
    it "returns hash list of id/iso_code pairs associated with classifications belonging to product with an hts_1" do
      expect(described_class.get_classifications(base_hash)).to eq [{id: 1, iso_code: 'US'}]
    end

    it "returns empty if product has no classifications" do
      base_hash = {"entity"=>{"core_module"=>"Product", "record_id"=>1}}
      expect(described_class.get_classifications(base_hash)).to be_empty
    end
  end

  describe :contains_hts_1? do
      
    it "returns true if classification hash contains a tariff with an hts_1 field" do
      class_hash = base_hash["entity"]["children"].first
      expect(described_class.contains_hts_1?(class_hash)).to eq true
    end

    it "returns false if tariff lacks an hts_1" do
      class_hash = base_hash["entity"]["children"].first
      class_hash["entity"]["children"].first["entity"]["model_fields"].merge!({"hts_hts_1" => "", "hts_hts_2" => "1111"})
      expect(described_class.contains_hts_1?(class_hash)).to eq false
    end

    it "returns false if tariff is missing altogether" do
      class_hash = {"entity"=>{"core_module"=>"Classification", "record_id"=>1, "model_fields"=>{"class_cntry_iso"=>"CA"}}}
      expect(described_class.contains_hts_1?(class_hash)).to eq false
    end
  end

  describe :filter_new_classifications do
    it "takes two hash lists of id/iso_code pairs and returns those in the second set that don't appear in the first" do
      old_bucket_classis = [{id: 1, iso_code: 'US'},{id: 2, iso_code: 'CA'}, {id: 3, iso_code: 'CN'}]
      new_bucket_classis = [{id: 1, iso_code: 'US'}, {id: 3, iso_code: 'CN'}, {id: 4, iso_code: 'AF'}, {id: 5, iso_code: 'MX'}]
      new_classis = [{id: 4, iso_code: 'AF'}, {id: 5, iso_code: 'MX'}]

      expect(described_class.filter_new_classifications(old_bucket_classis, new_bucket_classis)).to eq new_classis
    end
  end
end