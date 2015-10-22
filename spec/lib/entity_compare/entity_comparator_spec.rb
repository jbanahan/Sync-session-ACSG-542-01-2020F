require 'spec_helper'

describe OpenChain::EntityCompare::EntityComparator do
  before :each do
    @u = Factory(:user)
    @ord = Factory(:order)
    @comparator = Class.new do
      COMPARED ||= []
      COMPARED.clear
      def self.compare type, id, ob, op, ov, nb, np, nv
        COMPARED << [type, id, ob, op, ov, nb, np, nv]
      end

      def self.compared
        COMPARED
      end


    end
  end
  describe :process_by_id do
    it "should find EntitySnapshot and process" do
      es = EntitySnapshot.create!(recordable: @ord, user:@u, bucket: 'b', doc_path: 'd', version: 'v')
      described_class.should_receive(:process).with(instance_of(EntitySnapshot))

      described_class.process_by_id es.id
    end
  end
  describe :process do
    before :each do
      @comparator.stub(:delay).and_return(@comparator)
      OpenChain::EntityCompare::ComparatorRegistry.register @comparator
    end
    it "should handle object with one snapshot" do
      es = EntitySnapshot.create!(recordable: @ord, user:@u, bucket: 'b', doc_path: 'd', version: 'v')

      described_class.process(es)
      
      #should pass nil for the old items and the values for the new
      expect(@comparator.compared).to eq [['Order',@ord.id,nil,nil,nil,'b','d','v']]
    end
    it "should handle object with multiple unprocessed snapshots and no processed snapshots" do
      old_es = EntitySnapshot.create!(created_at: 1.day.ago, recordable: @ord, user:@u, bucket: 'ob', doc_path: 'od', version: 'ov')
      es = EntitySnapshot.create!(recordable: @ord, user:@u, bucket: 'b', doc_path: 'd', version: 'v')

      described_class.process(es)
      
      #should pass nil for the old items and the values for the new
      expect(@comparator.compared).to eq [['Order',@ord.id,nil,nil,nil,'b','d','v']]

      #all objects should be flagged as compared
      expect(EntitySnapshot.where('compared_at is null')).to be_empty
      
    end
    it "should handle object with multiple unprocessed snapshots and a processed snapshot" do
      processed_es = EntitySnapshot.create!(compared_at: 2.days.ago, created_at: 2.days.ago, recordable: @ord, user:@u, bucket: 'cb', doc_path: 'cd', version: 'cv')
      old_es = EntitySnapshot.create!(created_at: 1.day.ago, recordable: @ord, user:@u, bucket: 'ob', doc_path: 'od', version: 'ov')
      es = EntitySnapshot.create!(recordable: @ord, user:@u, bucket: 'b', doc_path: 'd', version: 'v')

      described_class.process(es)
      
      #should pass nil for the old items and the values for the new
      expect(@comparator.compared).to eq [['Order',@ord.id,'cb','cd','cv','b','d','v']]

      #all objects should be flagged as compared
      expect(EntitySnapshot.where('compared_at is null')).to be_empty
    end
    it "should noop when no unprocessed snapshots newer than the most recently processed" do
      old_es = EntitySnapshot.create!(created_at: 1.day.ago, recordable: @ord, user:@u, bucket: 'ob', doc_path: 'od', version: 'ov')
      processed_es = EntitySnapshot.create!(compared_at: 1.hour.ago, created_at: 1.hour.ago, recordable: @ord, user:@u, bucket: 'cb', doc_path: 'cd', version: 'cv')

      described_class.process(old_es)
      
      #should pass nil for the old items and the values for the new
      expect(@comparator.compared).to eq []

      expect(EntitySnapshot.where('compared_at is null').to_a).to eq [old_es]
    end
  end
end