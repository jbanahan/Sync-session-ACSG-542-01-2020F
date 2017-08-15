describe ErrorLogEntry do

  describe "purge" do
    subject { described_class }

    it "removes anything older than given date" do
      error = nil
      Timecop.freeze(Time.zone.now - 1.second) { error = ErrorLogEntry.create! }
      
      subject.purge Time.zone.now

      expect {error.reload}.to raise_error ActiveRecord::RecordNotFound
    end

    it "does not remove items newer than given date" do
      error = nil
      now = Time.zone.now
      Timecop.freeze(now + 1.second) { error = ErrorLogEntry.create! }
      
      subject.purge now

      expect {error.reload}.not_to raise_error
    end
  end
end