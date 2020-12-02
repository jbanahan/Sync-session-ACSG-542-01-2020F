describe DebugRecord do

  describe "purge" do
    subject { described_class }

    it "removes anything older than given date" do
      debug_record = nil
      Timecop.freeze(Time.zone.now - 1.second) { debug_record = DebugRecord.create! user: create(:user)}

      subject.purge Time.zone.now

      expect {debug_record.reload}.to raise_error ActiveRecord::RecordNotFound
    end

    it "does not remove items newer than given date" do
      debug_record = nil
      now = Time.zone.now
      Timecop.freeze(now + 1.second) { debug_record = DebugRecord.create! user: create(:user) }

      subject.purge now

      expect {debug_record.reload}.not_to raise_error
    end
  end
end
