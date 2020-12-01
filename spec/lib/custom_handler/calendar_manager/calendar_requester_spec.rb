describe OpenChain::CustomHandler::CalendarManager::CalendarRequester do
  subject { described_class }

  let (:us_hol) {FactoryBot.create(:calendar, calendar_type: 'USHol', year: now.year)}
  let (:ca_hol) {FactoryBot.create(:calendar, calendar_type: 'CAHol', year: 1.year.ago.year)}
  let (:now) { DateTime.now }

  describe "run_schedulable" do
    it "calls new_dates_needed with each calendar which does not have future events and are in the options" do
      FactoryBot.create(:calendar_event, calendar: us_hol, event_date: now)
      FactoryBot.create(:calendar_event, calendar: ca_hol, event_date: now)

      expect(subject).to receive(:new_dates_needed?).with('USHol').ordered.and_return(true)
      expect(subject).to receive(:new_dates_needed?).with('CAHol').ordered.and_return(true)
      subject.run_schedulable({'calendars' => ['USHol', 'CAHol']})
    end

    it "calls send_email with the email list provided in options" do
      FactoryBot.create(:calendar_event, calendar: us_hol, event_date: now)

      expect(subject).to receive(:send_email).with(['test@vandegriftinc.com', 'another@email.com'], ['USHol'])
      subject.run_schedulable({"calendars" => ['USHol'], 'emails' => ['test@vandegriftinc.com', 'another@email.com']})
    end
  end

  describe "new_dates_needed?" do
    it "returns true if a given calendar has no dates beyond one month" do
      expect(subject.new_dates_needed?('USHol')).to eq true
    end

    it "returns false if a given calendar does have dates beyond one month" do
      FactoryBot.create(:calendar_event, calendar: us_hol, event_date: now + 2.months)
      expect(subject.new_dates_needed?('USHol')).to eq false
    end

    it "returns true if there is no calendar for this year" do
      FactoryBot.create(:calendar_event, calendar: ca_hol, event_date: 1.year.ago + 1.month)
      expect(subject.new_dates_needed?('CAHol')).to eq true
    end
  end

  describe "send_email" do
    it "sends emails containing calendars to given emails" do
      subject.send_email(['test@vandegriftinc.com', 'another@email.com'], ['USHol'])

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["test@vandegriftinc.com", "another@email.com"]
      expect(mail.subject).to eq "VFI Track Calendar Dates are about to run out - Action Required"
      expect(mail.body).to match("The following calendars will run out of values next month:</br>- " +
        "USHol</br>Please add new values to the calendar using the upload process in place.")

      subject.send_email ['test@vandegriftinc.com', 'another@email.com'], ['USHol']
    end
  end
end
