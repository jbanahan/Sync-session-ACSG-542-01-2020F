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

  describe "email_me?" do
    let!(:master_setup) {
      stub_master_setup
    }

    subject {
      described_class.new exception_class: "ExceptionClass", error_message: "Error Message"
    }

    it "emails by default" do
      expect(subject.email_me?).to eq true
    end

    it "suppresses emailing error logs if custom feature enabled" do
      expect(master_setup).to receive(:custom_feature?).with("Suppress Exception Emails").and_return true

      expect(subject.email_me?).to eq false
    end

    it "suppresses email if another email of the same type was sent in last minute" do
      now = Time.zone.now
      Timecop.freeze(now) do
        ErrorLogEntry.create! exception_class: "ExceptionClass", error_message: "Error Message"
        expect(subject.email_me?).to eq false
      end
    end

    it "doesn't suppress email if another email of the same type was sent over a minute ago" do
      now = Time.zone.now - 61.seconds
      Timecop.freeze(now) do
        ErrorLogEntry.create! exception_class: "ExceptionClass", error_message: "Error Message"
      end

      expect(subject.email_me?).to eq true
    end
  end
end
