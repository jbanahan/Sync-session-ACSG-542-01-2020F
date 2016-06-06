require 'spec_helper'

describe OpenChain::BillingComparators::ProductComparator do
  describe :compare do
    it "exits if the type isn't 'Product'" do
      EntitySnapshot.should_not_receive(:where)
      described_class.compare('Entry', 'id', 'old_bucket', 'old_path', 'old_version', 'new_bucket', 'new_path', 'new_version')
    end

    it "runs comparisons" do
      es = Factory(:entity_snapshot, bucket: "new_bucket", doc_path: "new_path", version: "new_version")
      
      described_class.should_receive(:check_new_classification).with(id: 'id', old_bucket: 'old_bucket', old_path: 'old_path', old_version: 'old_version', 
                                                                    new_bucket: 'new_bucket', new_path: 'new_path', new_version: 'new_version', new_snapshot_id: es.id)
      
      described_class.compare('Product', 'id', 'old_bucket', 'old_path', 'old_version', 'new_bucket', 'new_path', 'new_version')
    end
  end

  describe :check_new_classification do
    before(:each) do 
      @class_1 = Factory(:classification)
      class_2 = Factory(:classification)
      class_3 = Factory(:classification)
      @class_list = [{id: @class_1.id, iso_code: 'US'},{id: class_2.id, iso_code: 'CA'}, {id: class_3.id, iso_code: 'CN'}]
      @es = Factory(:entity_snapshot)
    end

    it "creates a billable event for every classification on the product if the product is new" do

      described_class.should_receive(:get_classifications).with(nil, nil, nil).and_return []
      described_class.should_receive(:get_classifications).with('new_bucket', 'new_path', 'new_version').and_return @class_list
      described_class.should_receive(:filter_new_classifications).with([], @class_list).and_return @class_list
      described_class.check_new_classification(id: 9, old_bucket: nil, old_path: nil, old_version: nil, new_bucket: 'new_bucket', 
                                               new_path: 'new_path', new_version: 'new_version', new_snapshot_id: @es.id)

      expect(BillableEvent.count).to eq 3
      be = BillableEvent.all.sort.first
      expected = [@class_1, @es, "classification_new"]
      expect([be.billable_eventable, be.entity_snapshot, be.event_type]).to eq expected
    end

    it "creates a billable event for every classification not on the old version of the product" do
      class_4 = Factory(:classification)
      class_5 = Factory(:classification)
      class_list_2 = [{id: 1, iso_code: 'US'}, {id: 3, iso_code: 'CN'}, {id: 4, iso_code: 'AF'}, {id: 5, iso_code: 'MX'}]
      new_list = [{id: class_4.id, iso_code: 'AF'}, {id: class_5.id, iso_code: 'MX'}]

      described_class.should_receive(:get_classifications).with('old_bucket', 'old_path', 'old_version').and_return @class_list
      described_class.should_receive(:get_classifications).with('new_bucket', 'new_path', 'new_version').and_return class_list_2
      described_class.should_receive(:filter_new_classifications).with(@class_list, class_list_2).and_return new_list
      
      described_class.check_new_classification(id: 9, old_bucket: 'old_bucket', old_path: 'old_path', old_version: 'old_version', 
                                               new_bucket: 'new_bucket', new_path: 'new_path', new_version: 'new_version', new_snapshot_id: @es.id)
      
      expect(BillableEvent.count). to eq 2
      be_1, be_2 = BillableEvent.all.sort
      expected = [class_4, @es, "classification_new"]
      expect([be_1.billable_eventable, be_1.entity_snapshot, be_1.event_type]).to eq expected
      expected = [class_5, @es, "classification_new"]
      expect([be_2.billable_eventable, be_2.entity_snapshot, be_2.event_type]).to eq expected
    end
  end

  describe :get_classifications do
    it "returns hash list of id/iso_code pairs associated with classifications belonging to product" do
      class_list = [{id: 1, iso_code: 'US'},{id: 2, iso_code: 'CA'}]
      json_hash = {"entity"=>{"core_module"=>"Product", "record_id"=>1, "children"=>
                  [{"entity"=>{"core_module"=>"Classification", "record_id"=>1, "model_fields"=>{"class_cntry_iso"=>"US"}}}, 
                   {"entity"=>{"core_module"=>"Classification", "record_id"=>2, "model_fields"=>{"class_cntry_iso"=>"CA"}}}]}}
      described_class.should_receive(:get_json_hash).with("bucket", "path", "version").and_return json_hash
      expect(described_class.get_classifications("bucket", "path", "version")).to eq class_list
    end

    it "returns empty if product has no classifications" do
      json_hash = {"entity"=>{"core_module"=>"Product", "record_id"=>1}}
      described_class.should_receive(:get_json_hash).with("bucket", "path", "version").and_return json_hash
      expect(described_class.get_classifications("bucket", "path", "version")).to be_empty
    end

    it "returns empty if bucket is empty" do
      json_hash = {}
      described_class.should_receive(:get_json_hash).with(nil, nil, nil).and_return json_hash
      expect(described_class.get_classifications(nil, nil, nil)).to be_empty
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