describe EntitySnapshotFailure do

  let (:snapshot) { EntitySnapshot.create! recordable: Factory(:entry), user: Factory(:user)}
  let (:failure) { EntitySnapshotFailure.create! snapshot: snapshot, snapshot_json: "json"}

  describe "fix_snapshot_data" do

    it "stores snapshot data and processes the snapshot" do
      expect(EntitySnapshot).to receive(:store_snapshot_json).with(snapshot, "json", record_failure: false).and_return true
      expect(OpenChain::EntityCompare::EntityComparator).to receive(:handle_snapshot).with snapshot

      expect(described_class.fix_snapshot_data failure).to eq true

      expect {failure.reload}.to raise_error ActiveRecord::RecordNotFound
    end

    it "no-ops if storage call fails" do
      expect(EntitySnapshot).to receive(:store_snapshot_json).with(snapshot, "json", record_failure: false).and_return false
      expect(OpenChain::EntityCompare::EntityComparator).not_to receive(:handle_snapshot)

      expect(described_class.fix_snapshot_data failure).to eq false
      expect {failure.reload}.not_to raise_error
    end
  end

  describe "run_schedulable" do

    before(:each) { failure }

    it "fixes snapshot data" do
      expect(EntitySnapshot).to receive(:store_snapshot_json).with(snapshot, "json", record_failure: false).and_return true
      described_class.run_schedulable
      expect {failure.reload}.to raise_error ActiveRecord::RecordNotFound
    end

    it "handles errors raised from fixing" do
      failure_2 = EntitySnapshotFailure.create! snapshot: snapshot, snapshot_json: "json"
      expect(described_class).to receive(:find_each).and_yield(failure).and_yield(failure_2)

      error = StandardError.new
      expect(described_class).to receive(:fix_snapshot_data).with(failure).and_raise error
      expect(error).to receive(:log_me)

      expect(described_class).to receive(:fix_snapshot_data).with(failure_2)

      described_class.run_schedulable
    end
  end
end
