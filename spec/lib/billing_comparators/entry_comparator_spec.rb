describe OpenChain::BillingComparators::EntryComparator do
  describe "compare" do
    it "exits if the type isn't 'Entry'" do
      expect(EntitySnapshot).not_to receive(:where)
      described_class.compare('Product', 1, 'old_bucket', 'old_path', 'old_version', 'new_bucket', 'new_path', 'new_version')
    end

    it "runs comparisons" do
      es = Factory(:entity_snapshot, bucket: 'new_bucket', doc_path: 'new_path', version: 'new_version')
      expect(described_class).to receive(:check_new_entry).with(id: 2, old_bucket: 'old_bucket', old_path: 'old_path', old_version: 'old_version',
                                                            new_bucket: 'new_bucket', new_path: 'new_path', new_version: 'new_version', new_snapshot_id: es.id)

      described_class.compare('Entry', 2, 'old_bucket', 'old_path', 'old_version', 'new_bucket', 'new_path', 'new_version')
    end
  end

  describe "check_new_entry" do
    it "creates a billable event for a new entry" do
      es = Factory(:entity_snapshot, bucket: 'new_bucket', doc_path: 'new_path', version: 'new_version')
      ent = Factory(:entry)
      described_class.check_new_entry(id: ent.id, old_bucket: nil, old_path: nil, old_version: nil, new_bucket: 'new_bucket',
                                      new_path: 'new_path', new_version: 'new_version', new_snapshot_id: es.id)

      expect(BillableEvent.count).to eq 1
      be = BillableEvent.first
      expected = [ent, es, "entry_new"]
      expect([be.billable_eventable, be.entity_snapshot, be.event_type]).to eq expected
    end

    it "ignores updated entries" do
      expect(BillableEvent).not_to receive(:create!)
      described_class.check_new_entry(id: 1, old_bucket: 'old_bucket', old_path: 'old_path', old_version: 'old_version', new_bucket: 'new_bucket',
                                      new_path: 'new_path', new_version: 'new_version', new_snapshot_id: 1)
    end
  end
end