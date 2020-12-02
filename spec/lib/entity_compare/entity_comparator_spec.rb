describe OpenChain::EntityCompare::EntityComparator do
  subject { described_class }

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

  let (:user) { create(:user) }
  let (:order) { create(:order) }

  describe "process_by_id" do
    it "should find EntitySnapshot and process" do
      es = EntitySnapshot.create!(recordable: order, user:user, bucket: 'b', doc_path: 'd', version: 'v')
      expect(subject).to receive(:process).with(instance_of(EntitySnapshot))

      subject.process_by_id "EntitySnapshot", es.id
    end
  end
  describe "process" do
    before :each do
      allow(subject).to receive(:delay_options).and_return({delay_opts: true})
      allow(comparator).to receive(:delay).with({delay_opts: true}).and_return(comparator)
      OpenChain::EntityCompare::ComparatorRegistry.register comparator
    end
    it "should handle object with one snapshot" do
      es = EntitySnapshot.create!(recordable: order, user:user, bucket: 'b', doc_path: 'd', version: 'v')

      subject.process(es)

      # should pass nil for the old items and the values for the new
      expect(comparator.compared).to eq [['Order', order.id, nil, nil, nil, 'b', 'd', 'v']]

      log = EntityComparatorLog.where(recordable_type: "Order", recordable_id: order.id).first
      expect(log).not_to be_nil
      expect(log.old_bucket).to be_nil
      expect(log.old_path).to be_nil
      expect(log.old_version).to be_nil
      expect(log.new_bucket).to eq "b"
      expect(log.new_path).to eq "d"
      expect(log.new_version).to eq "v"
    end

    it "should handle object with multiple unprocessed snapshots and no processed snapshots" do
      old_es = EntitySnapshot.create!(created_at: 1.day.ago, recordable: order, user:user, bucket: 'ob', doc_path: 'od', version: 'ov')
      es = EntitySnapshot.create!(recordable: order, user:user, bucket: 'b', doc_path: 'd', version: 'v')

      subject.process(es)

      # should pass nil for the old items and the values for the new
      expect(comparator.compared).to eq [['Order', order.id, nil, nil, nil, 'b', 'd', 'v']]

      # all objects should be flagged as compared
      expect(EntitySnapshot.where('compared_at is null')).to be_empty

      log = EntityComparatorLog.where(recordable_type: "Order", recordable_id: order.id).first
      expect(log).not_to be_nil
      # These should all be nil, since the old snapshot was not processed either.
      expect(log.old_bucket).to be_nil
      expect(log.old_path).to be_nil
      expect(log.old_version).to be_nil
      expect(log.new_bucket).to eq "b"
      expect(log.new_path).to eq "d"
      expect(log.new_version).to eq "v"
    end

    it "should handle object with multiple unprocessed snapshots and a processed snapshot" do
      processed_es = EntitySnapshot.create!(compared_at: 2.days.ago, created_at: 2.days.ago, recordable: order, user:user, bucket: 'cb', doc_path: 'cd', version: 'cv')
      old_es = EntitySnapshot.create!(created_at: 1.day.ago, recordable: order, user:user, bucket: 'ob', doc_path: 'od', version: 'ov')
      es = EntitySnapshot.create!(recordable: order, user:user, bucket: 'b', doc_path: 'd', version: 'v')

      subject.process(es)

      # should pass nil for the old items and the values for the new
      expect(comparator.compared).to eq [['Order', order.id, 'cb', 'cd', 'cv', 'b', 'd', 'v']]

      # all objects should be flagged as compared
      expect(EntitySnapshot.where('compared_at is null')).to be_empty

      log = EntityComparatorLog.where(recordable_type: "Order", recordable_id: order.id).first
      expect(log).not_to be_nil
      expect(log.old_bucket).to eq "cb"
      expect(log.old_path).to eq "cd"
      expect(log.old_version).to eq "cv"
      expect(log.new_bucket).to eq "b"
      expect(log.new_path).to eq "d"
      expect(log.new_version).to eq "v"
    end

    it "should noop when no unprocessed snapshots newer than the most recently processed" do
      old_es = EntitySnapshot.create!(created_at: 1.day.ago, recordable: order, user:user, bucket: 'ob', doc_path: 'od', version: 'ov')
      processed_es = EntitySnapshot.create!(compared_at: 1.hour.ago, created_at: 1.hour.ago, recordable: order, user:user, bucket: 'cb', doc_path: 'cd', version: 'cv')

      subject.process(old_es)

      # should pass nil for the old items and the values for the new
      expect(comparator.compared).to eq []

      expect(EntitySnapshot.where('compared_at is null').to_a).to eq [old_es]
      expect(EntityComparatorLog.where(recordable_type: "Order", recordable_id: order.id).first).to be_nil
    end

    it "should handle newest when two written at same time" do
      create_time = Time.now
      first_es = EntitySnapshot.create!(created_at: create_time, recordable: order, user:user, bucket: 'ob', doc_path: 'od', version: 'ov')
      EntitySnapshot.create!(created_at: create_time, recordable: order, user:user, bucket: 'ob2', doc_path: 'od2', version: 'ov2')
      subject.process(first_es)

      # should pass nil for the old items and the values for the new
      expect(comparator.compared).to eq [['Order', order.id, nil, nil, nil, 'ob2', 'od2', 'ov2']]

      expect(EntitySnapshot.where('compared_at is null').to_a).to eq []
      log = EntityComparatorLog.where(recordable_type: "Order", recordable_id: order.id).first
      expect(log).not_to be_nil
      # These should all be nil, since the old snapshot was not processed either.
      expect(log.old_bucket).to be_nil
      expect(log.old_path).to be_nil
      expect(log.old_version).to be_nil
      expect(log.new_bucket).to eq "ob2"
      expect(log.new_path).to eq "od2"
      expect(log.new_version).to eq "ov2"
    end

    it "should handle newest when two processed from the same time" do
      old_time = 2.days.ago
      EntitySnapshot.create!(compared_at: old_time, created_at: old_time, recordable: order, user:user, bucket: 'cb', doc_path: 'cd', version: 'cv')
      # match this one
      EntitySnapshot.create!(compared_at: old_time, created_at: old_time, recordable: order, user:user, bucket: 'cb', doc_path: 'cd', version: 'cv2')
      to_process = EntitySnapshot.create!(created_at: Time.now, recordable: order, user:user, bucket: 'ob2', doc_path: 'od2', version: 'ov2')
      subject.process(to_process)
      expect(comparator.compared).to eq [['Order', order.id, 'cb', 'cd', 'cv2', 'ob2', 'od2', 'ov2']]

      log = EntityComparatorLog.where(recordable_type: "Order", recordable_id: order.id).first
      expect(log).not_to be_nil
      expect(log.old_bucket).to eq "cb"
      expect(log.old_path).to eq "cd"
      expect(log.old_version).to eq "cv2"
      expect(log.new_bucket).to eq "ob2"
      expect(log.new_path).to eq "od2"
      expect(log.new_version).to eq "ov2"
    end

    it "skips snapshots that don't have bucket written" do
      processed_es = EntitySnapshot.create!(compared_at: 2.days.ago, created_at: 2.days.ago, recordable: order, user:user, bucket: 'cb', doc_path: 'cd', version: 'cv')
      old_es = EntitySnapshot.create!(created_at: 1.day.ago, recordable: order, user:user, bucket: 'ob', doc_path: 'od', version: 'ov')
      es = EntitySnapshot.create!(recordable: order, user:user)

      subject.process(es)

      # Normally, we'd be expecting the es snapshot to process, but since it doesn't have a bucket or doc path, it shouldn't get picked up yet.
      expect(comparator.compared).to eq [['Order', order.id, 'cb', 'cd', 'cv', 'ob', 'od', 'ov']]

      # all objects should be flagged as compared
      expect(EntitySnapshot.where('compared_at is null')).to include es

      log = EntityComparatorLog.where(recordable_type: "Order", recordable_id: order.id).first
      expect(log).not_to be_nil
      expect(log.old_bucket).to eq "cb"
      expect(log.old_path).to eq "cd"
      expect(log.old_version).to eq "cv"
      expect(log.new_bucket).to eq "ob"
      expect(log.new_path).to eq "od"
      expect(log.new_version).to eq "ov"
    end

    it "skips snapshots where the recordable entity is missing" do
      es = EntitySnapshot.create!(recordable: order, user:user, bucket: 'b', doc_path: 'd', version: 'v')
      order.delete
      es.reload

      subject.process(es)
      expect(EntityComparatorLog.where(recordable_type: "Order", recordable_id: order.id).first).to be_nil
    end

    it "handles nil registry" do
      expect(subject).to receive(:registry).and_return nil

      subject.process EntitySnapshot.create!(recordable: order, user:user, bucket: 'b', doc_path: 'd', version: 'v')

      expect(EntityComparatorLog.where(recordable_type: "Order", recordable_id: order.id).first).to be_nil
    end
  end

  describe "handle_snapshot" do
    let (:snapshot) { EntitySnapshot.new id: 6, recordable: order }

    context "non-test environment" do
      before :each do
        allow(subject).to receive(:delay_options).and_return({delay_opts: true})
        expect(subject).to receive(:test?).and_return false
      end

      it "delays process_by_id call if there is a comparator set to handle the snapshot" do
        OpenChain::EntityCompare::ComparatorRegistry.register comparator

        expect(subject).to receive(:delay).with({delay_opts: true}).and_return subject
        expect(subject).to receive(:process_by_id).with("EntitySnapshot", snapshot.id)

        subject.handle_snapshot snapshot
      end

      it "does not call process_by_id if no comparator is set to handle the snapshot" do
        expect(subject).not_to receive(:delay)

        subject.handle_snapshot snapshot
      end

      it "skips process by id if snapshot's recordable type is disabled" do
        # Make sure there's a comparator there to process, so we know that it's not not calling the process_by_id method due to the logic
        # and not that there's no comparators.
        OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::EntityCompare::ProductComparator::StaleTariffComparator
        ms = stub_master_setup
        expect(ms).to receive(:custom_feature?).with("Disable Product Snapshot Comparators").and_return true

        product = create(:product, unique_identifier: "UAPARTS-123")
        es = EntitySnapshot.new id: 6, recordable: product

        expect(subject).not_to receive(:delay)

        subject.handle_snapshot es
      end

      it "skips process_by_id if object is closed and closed snapshot comparators is disabled" do
        # Just use any comparator for a module that responds to closed?
        OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::LumberLiquidators::LumberOrderChangeComparator
        ms = stub_master_setup
        expect(ms).to receive(:custom_feature?).with("Disable Order Snapshot Comparators").and_return false
        expect(ms).to receive(:custom_feature?).with("Disable Comparators For Closed Objects").and_return true

        order = Order.new
        expect(order).to receive(:closed?).and_return true
        es = EntitySnapshot.new id: 5, recordable: order

        expect(subject).not_to receive(:delay)

        subject.handle_snapshot es
      end

      it "does not skip process_by_id if object is not closed and closed snapshot comparators is disabled" do
        # Just use any comparator for a module that responds to closed?
        OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::CustomHandler::LumberLiquidators::LumberOrderChangeComparator
        ms = stub_master_setup
        expect(ms).to receive(:custom_feature?).with("Disable Order Snapshot Comparators").and_return false
        expect(ms).to receive(:custom_feature?).with("Disable Comparators For Closed Objects").and_return true

        order = Order.new
        expect(order).to receive(:closed?).and_return false
        es = EntitySnapshot.new id: 5, recordable: order

        expect(subject).to receive(:delay).and_return subject
        expect(subject).to receive(:process_by_id)

        subject.handle_snapshot es
      end
    end

    context "test environment" do
      it "does not skip process by id if test environment" do
        # Make sure there's a comparator there to process
        OpenChain::EntityCompare::ComparatorRegistry.register OpenChain::EntityCompare::ProductComparator::StaleTariffComparator
        product = create(:product, unique_identifier: "UAPARTS-123")
        es = EntitySnapshot.new id: 6, recordable: product

        expect(subject).to receive(:delay).and_return subject
        expect(subject).to receive(:process_by_id).with("EntitySnapshot", snapshot.id)

        subject.handle_snapshot es
      end
    end
  end

  describe "delay_options" do
    it "returns default options" do
      expect(subject.delay_options).to eq({priority: 10})
    end

    it "allows overriding priority" do
      expect(subject.delay_options priority: 100).to eq({priority: 100})
    end

    it "allows assigning the queue for processing using application config" do
      expect(MasterSetup).to receive(:config_value).with(:snapshot_processing_queue).and_yield "test_queue"
      expect(subject.delay_options).to eq({priority: 10, queue: "test_queue"})
    end
  end
end
