describe OpenChain::CustomHandler::Kirklands::KirklandsEntryDutyComparator do

  subject { described_class }

  describe "accept?" do
    let (:entry) { create(:entry, customer_number: "KLANDS", last_7501_print: Time.zone.parse("2020-03-02 05:00")) }
    let (:snapshot) { EntitySnapshot.new recordable: entry }

    it "accepts Kirklands entries with Last 7501 Print Dates" do
      expect(subject.accept? snapshot).to eq true
    end

    it "does not accept entries with missing Last 7501 Print Dates" do
      entry.last_7501_print = nil
      expect(subject.accept? snapshot).to eq false
    end

    it "does not accept non-Kirklands entries" do
      entry.customer_number = "NOTKLANDS"
      expect(subject.accept? snapshot).to eq false
    end

    it "does not accept non-Kirklands entries" do
      entry.customer_number = "NOTKLANDS"
      expect(subject.accept? snapshot).to eq false
    end

    it "does not accept entries printed prior to March 2, 2020" do
      # Because we're in UTC zone, this is still 3/1 in Eastern timezone, so it should reject
      entry.last_7501_print = Time.zone.parse("2020-03-02 02:00")
      expect(subject.accept? snapshot).to eq false
    end
  end

  describe "generate_and_send" do
    let (:entry) { create(:entry, customer_number: "KLANDS", last_7501_print: Time.zone.parse("2020-03-02 05:00")) }
    let (:new_snapshot) { JSON.parse(CoreModule.find_by_object(entry).entity_json(entry)) }
    let (:old_snapshot) { JSON.parse(CoreModule.find_by_object(entry).entity_json(entry)) }

    it "generates file for entry with Last 7501 Print date that hasn't been sent before" do
      expect_any_instance_of(OpenChain::CustomHandler::Kirklands::KirklandsEntryDutyFileGenerator).to receive(:generate_and_send).with(new_snapshot)
      subject.generate_and_send entry, nil, new_snapshot
    end

    it "generates file for entry that's already been sent, but has an updated last_7501_print" do
      entry.sync_records.create! trading_partner: "KIRKLANDS_DUTY", sent_at: Time.zone.now
      os = old_snapshot
      entry.update! last_7501_print: (Time.zone.now + 1.day)
      expect_any_instance_of(OpenChain::CustomHandler::Kirklands::KirklandsEntryDutyFileGenerator).to receive(:generate_and_send).with(new_snapshot)

      subject.generate_and_send entry, os, new_snapshot
    end

    it "does not generate a file for an entry that's alraedy sent that has not had an updated 7501 print" do
      entry.sync_records.create! trading_partner: "KIRKLANDS_DUTY", sent_at: Time.zone.now
      expect_any_instance_of(OpenChain::CustomHandler::Kirklands::KirklandsEntryDutyFileGenerator).not_to receive(:generate_and_send)

      subject.generate_and_send entry, new_snapshot, new_snapshot
    end
  end

  describe "compare" do
    let (:entry) { create(:entry, customer_number: "KLANDS", last_7501_print: Time.zone.parse("2020-03-02 05:00")) }
    let (:new_snapshot) { JSON.parse(CoreModule.find_by_object(entry).entity_json(entry)) }
    let (:old_snapshot) { JSON.parse(CoreModule.find_by_object(entry).entity_json(entry)) }

    it "finds entity and hashes then calls generate and send" do
      expect(subject).to receive(:generate_and_send).with(entry, old_snapshot, new_snapshot)
      expect(subject).to receive(:get_json_hash).with("old_bucket", "old_path", "old_version").and_return old_snapshot
      expect(subject).to receive(:get_json_hash).with("new_bucket", "new_path", "new_version").and_return old_snapshot

      subject.compare nil, nil, "old_bucket", "old_path", "old_version", "new_bucket", "new_path", "new_version"
    end
  end
end