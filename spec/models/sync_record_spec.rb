describe SyncRecord do
  describe "problem?" do
    it 'should be a problem if sent more than 1 hour ago and not confirmed after sent time' do
      expect(SyncRecord.new(:sent_at=>2.hours.ago)).to be_problem
    end
    it 'should be a problem if has fialure message' do
      expect(SyncRecord.new(:failure_message=>'a')).to be_problem
    end
    it 'should not be a problem if sent less than 1 hour ago and not confirmed' do
      expect(SyncRecord.new(:sent_at=>55.minutes.ago)).not_to be_problem
    end
    it 'should not be a problem if confirmed after sent' do
      expect(SyncRecord.new(:sent_at=>2.hours.ago, :confirmed_at=>1.hour.ago)).not_to be_problem
    end
  end

  describe 'problems scope' do
    before :each do
      @p = Factory(:product)
    end
    it 'should be a problem if sent more than 1 hour ago and not confirmed after sent time' do
      sr = @p.sync_records.create!(:trading_partner=>'MSLE', :sent_at=>2.hours.ago)
      probs = SyncRecord.problems
      expect(probs.first).to eq(sr)
    end
    it 'should be a problem if has failure message' do
      sr = @p.sync_records.create!(:trading_partner=>'MSLE', :failure_message=>'a')
      expect(SyncRecord.problems.first).to eq(sr)
    end
    it 'should not be a problem if sent less than 1 hour ago and not confirmed' do
      sr = @p.sync_records.create!(:trading_partner=>'MSLE', :sent_at=>55.minutes.ago)
      expect(SyncRecord.problems).to be_empty
    end
    it 'should not be a problem if confirmed after sent' do
      sr = @p.sync_records.create!(:trading_partner=>'MSLE', :sent_at=>2.hours.ago, :confirmed_at=>1.hour.ago)
      expect(SyncRecord.problems).to be_empty
    end
  end

  describe "copy_attributes_to" do
    it "copies all non-identifying attributes to another record" do
      sr = SyncRecord.new id: 1, syncable_id: 2, syncable_type: "Type", created_at: Time.zone.now, updated_at: Time.zone.now, trading_partner: "test", sent_at: Time.zone.now, confirmed_at: (Time.zone.now + 1.minute),
                            confirmation_file_name: "file.txt", failure_message: 'failed', fingerprint: "Fingerprint", ignore_updates_before: (Time.zone.now + 2.minutes)

      sr2 = SyncRecord.new
      sr.copy_attributes_to sr2

      expect(sr2.id).to be_nil
      expect(sr2.syncable_id).to be_nil
      expect(sr2.syncable_type).to be_nil
      expect(sr2.created_at).to be_nil
      expect(sr2.updated_at).to be_nil
      expect(sr2.trading_partner).to eq "test"
      expect(sr2.sent_at).to eq sr.sent_at
      expect(sr2.confirmed_at).to eq sr.confirmed_at
      expect(sr2.confirmation_file_name).to eq "file.txt"
      expect(sr2.failure_message).to eq "failed"
      expect(sr2.fingerprint).to eq "Fingerprint"
      expect(sr2.ignore_updates_before).to eq sr.ignore_updates_before
    end
  end

  describe "find_or_build_sync_record" do
    it "builds a new sync record" do
      entry = Entry.new
      entry.sync_records.build(trading_partner: "AnotherType", sent_at: Time.zone.now)

      sr = SyncRecord.find_or_build_sync_record entry, "SomeType"
      expect(sr).not_to be_nil
      expect(sr.trading_partner).to eq "SomeType"
      expect(sr.sent_at).to be_nil
      expect(entry.sync_records.find {|r| r == sr }).not_to be_nil
    end

    it "finds an existing sync record" do
      entry = Entry.new
      entry.sync_records.build(trading_partner: "SomeType", sent_at: Time.zone.now)

      sr = SyncRecord.find_or_build_sync_record entry, "SomeType"
      expect(sr).not_to be_nil
      expect(sr.trading_partner).to eq "SomeType"
      expect(sr.sent_at).not_to be_nil
      expect(entry.sync_records.find_all {|r| r.trading_partner == "SomeType" }.length).to eq 1
    end
  end

end
