describe History do

  describe "purge" do
    subject { described_class }

    it "removes anything older than given date" do
      history = nil
      Timecop.freeze(Time.zone.now - 1.second) { history = History.create! history_type: "test"}

      subject.purge Time.zone.now

      expect {history.reload}.to raise_error ActiveRecord::RecordNotFound
    end

    it "does not remove items newer than given date" do
      history = nil
      now = Time.zone.now
      Timecop.freeze(now + 1.second) { history = History.create! history_type: "test" }

      subject.purge now

      expect {history.reload}.not_to raise_error
    end
  end
end
