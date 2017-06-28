require 'spec_helper'

describe OpenChain::EntityCompare::EntityComparator do
  let (:comparator) {
    Class.new do
      COMPARED ||= []
      COMPARED.clear
      def self.compare type, id, ob, op, ov, nb, np, nv
        COMPARED << [type, id, ob, op, ov, nb, np, nv]
      end

      def self.accept? snapshot
        snapshot.recordable_type == "Order"
      end

      def self.compared
        COMPARED
      end
    end
  }

  let (:user) { Factory(:user) }
  let (:order) { Factory(:order) }

  describe "process_by_id" do
    it "should find EntitySnapshot and process" do
      es = EntitySnapshot.create!(recordable: order, user:user, bucket: 'b', doc_path: 'd', version: 'v')
      expect(described_class).to receive(:process).with(instance_of(EntitySnapshot))

      described_class.process_by_id es.id
    end
  end
  describe "process" do
    before :each do
      allow(comparator).to receive(:delay).and_return(comparator)
      OpenChain::EntityCompare::ComparatorRegistry.register comparator
    end
    it "should handle object with one snapshot" do
      es = EntitySnapshot.create!(recordable: order, user:user, bucket: 'b', doc_path: 'd', version: 'v')

      described_class.process(es)

      #should pass nil for the old items and the values for the new
      expect(comparator.compared).to eq [['Order',order.id,nil,nil,nil,'b','d','v']]
    end
    it "should handle object with multiple unprocessed snapshots and no processed snapshots" do
      old_es = EntitySnapshot.create!(created_at: 1.day.ago, recordable: order, user:user, bucket: 'ob', doc_path: 'od', version: 'ov')
      es = EntitySnapshot.create!(recordable: order, user:user, bucket: 'b', doc_path: 'd', version: 'v')

      described_class.process(es)

      #should pass nil for the old items and the values for the new
      expect(comparator.compared).to eq [['Order',order.id,nil,nil,nil,'b','d','v']]

      #all objects should be flagged as compared
      expect(EntitySnapshot.where('compared_at is null')).to be_empty

    end
    it "should handle object with multiple unprocessed snapshots and a processed snapshot" do
      processed_es = EntitySnapshot.create!(compared_at: 2.days.ago, created_at: 2.days.ago, recordable: order, user:user, bucket: 'cb', doc_path: 'cd', version: 'cv')
      old_es = EntitySnapshot.create!(created_at: 1.day.ago, recordable: order, user:user, bucket: 'ob', doc_path: 'od', version: 'ov')
      es = EntitySnapshot.create!(recordable: order, user:user, bucket: 'b', doc_path: 'd', version: 'v')

      described_class.process(es)

      #should pass nil for the old items and the values for the new
      expect(comparator.compared).to eq [['Order',order.id,'cb','cd','cv','b','d','v']]

      #all objects should be flagged as compared
      expect(EntitySnapshot.where('compared_at is null')).to be_empty
    end
    it "should noop when no unprocessed snapshots newer than the most recently processed" do
      old_es = EntitySnapshot.create!(created_at: 1.day.ago, recordable: order, user:user, bucket: 'ob', doc_path: 'od', version: 'ov')
      processed_es = EntitySnapshot.create!(compared_at: 1.hour.ago, created_at: 1.hour.ago, recordable: order, user:user, bucket: 'cb', doc_path: 'cd', version: 'cv')

      described_class.process(old_es)

      #should pass nil for the old items and the values for the new
      expect(comparator.compared).to eq []

      expect(EntitySnapshot.where('compared_at is null').to_a).to eq [old_es]
    end

    it "should handle newest when two written at same time" do
      create_time = Time.now
      first_es = EntitySnapshot.create!(created_at: create_time, recordable: order, user:user, bucket: 'ob', doc_path: 'od', version: 'ov')
      EntitySnapshot.create!(created_at: create_time, recordable: order, user:user, bucket: 'ob2', doc_path: 'od2', version: 'ov2')
      described_class.process(first_es)

      #should pass nil for the old items and the values for the new
      expect(comparator.compared).to eq [['Order',order.id,nil, nil, nil,'ob2','od2','ov2']]

      expect(EntitySnapshot.where('compared_at is null').to_a).to eq []
    end
    it "should handle newest when two processed from the same time" do
      old_time = 2.days.ago
      EntitySnapshot.create!(compared_at: old_time, created_at: old_time, recordable: order, user:user, bucket: 'cb', doc_path: 'cd', version: 'cv')
      # match this one
      EntitySnapshot.create!(compared_at: old_time, created_at: old_time, recordable: order, user:user, bucket: 'cb', doc_path: 'cd', version: 'cv2')
      to_process = EntitySnapshot.create!(created_at: Time.now, recordable: order, user:user, bucket: 'ob2', doc_path: 'od2', version: 'ov2')
      described_class.process(to_process)
      expect(comparator.compared).to eq [['Order',order.id,'cb','cd','cv2','ob2','od2','ov2']]
    end

    it "skips snapshots that don't have bucket written" do
      processed_es = EntitySnapshot.create!(compared_at: 2.days.ago, created_at: 2.days.ago, recordable: order, user:user, bucket: 'cb', doc_path: 'cd', version: 'cv')
      old_es = EntitySnapshot.create!(created_at: 1.day.ago, recordable: order, user:user, bucket: 'ob', doc_path: 'od', version: 'ov')
      es = EntitySnapshot.create!(recordable: order, user:user)

      described_class.process(es)

      #Normally, we'd be expecting the es snapshot to process, but since it doesn't have a bucket or doc path, it shouldn't get picked up yet.
      expect(comparator.compared).to eq [['Order',order.id,'cb','cd','cv','ob','od','ov']]

      #all objects should be flagged as compared
      expect(EntitySnapshot.where('compared_at is null')).to include es
    end
  end

  describe "handle_snapshot" do
    let (:snapshot) { EntitySnapshot.new id: 6, recordable: order }

    it "delays process_by_id call if there is a comparator set to handle the snapshot" do
      OpenChain::EntityCompare::ComparatorRegistry.register comparator

      expect(described_class).to receive(:delay).with(priority: 10).and_return described_class
      expect(described_class).to receive(:process_by_id).with(snapshot.id)

      described_class.handle_snapshot snapshot
    end

    it "does not call process_by_id if no comparator is set to handle the snapshot" do
      expect(described_class).not_to receive(:delay)

      described_class.handle_snapshot snapshot
    end

    it "skips process by id if product is for UAPARTS" do
      # Make sure there's a comparator there to process, so we know that it's not not calling the process_by_id method due to the logic
      # and not that there's no comparators.
      OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::EntityCompare::ProductComparator::StaleTariffComparator
      ms = stub_master_setup
      expect(ms).to receive(:system_code).and_return "www-vfitrack-net"

      product = Factory(:product, unique_identifier: "UAPARTS-123")
      es = EntitySnapshot.new id: 6, recordable: product

      expect(described_class).not_to receive(:delay)

      described_class.handle_snapshot es
    end
  end
end
