describe OpenChain::CustomHandler::CalendarManager::CalendarUploadParser do
  subject { described_class.new(custom_file) }

  let(:ms) { stub_master_setup }
  let(:user) { Factory(:master_user) }

  let (:file_contents) do
    [
      ["Calendar Type", "Calendar Year", "Calendar Company", "Calendar Event Date", "Calendar Event Label"],
      ["USHol", 2020, nil, "2020-09-18", "A new event"]
    ]
  end
  let (:custom_file) do
    cf = Factory.create(:custom_file, uploaded_by: user, attached_file_name: "test.csv")
    allow(cf).to receive(:path).and_return "/path/to/file.xlsx"
    cf
  end

  let(:company) {Factory.create(:company, name: "Vandegrift Inc")}

  describe "process" do
    it 'sends each line of the file to process_row' do
      allow(subject).to receive(:foreach).with(custom_file, skip_headers: true, skip_blank_lines: true).and_yield(file_contents[1], 1)
      allow(subject).to receive(:message_to_user).with(user, []).and_return []

      expect(subject).to receive(:process_row).with(file_contents[1], 1, [])

      subject.process user
    end

    it 'passes any errors to message_to_user' do
      row = ["USHol", 2020, nil, "2020-09-18", "A new event"]
      expect(subject).to receive(:foreach).with(custom_file, skip_headers: true, skip_blank_lines: true).and_yield(row, 1)
      allow(subject).to receive(:process_row).with(row, 1, []).and_raise(StandardError.new("Some Error"))

      subject.process user
      m = user.messages.first
      expect(m.subject).to eq "File Processing Complete With Errors"
      expect(m.body).to eq "Calendar upload processing for file test.csv is complete.\n\nFailed to process calendar 2020 - USHol due to the following error: Some Error"
    end
  end

  describe "process_row" do
    it "creates a calendar and event given a row and row count" do
      subject.send(:process_row, file_contents[1], 1, [])

      expect(Calendar.count).to eq 1
      expect(CalendarEvent.count).to eq 1
    end

    it "does not add an event if it already exists" do
      c = Factory(:calendar, year: 2020, calendar_type: "USHol")
      Factory(:calendar_event, calendar: c, event_date: Date.parse("2020-09-18"), label: "A new event")
      subject.send(:process_row, file_contents[1], 1, [])

      expect(CalendarEvent.count).to eq 1
    end

    it "does not add a new calendar if it already exists" do
      Factory(:calendar, year: 2020, calendar_type: "USHol")
      subject.send(:process_row, file_contents[1], 1, [])

      expect(Calendar.count).to eq 1
    end

    it "assigns a company to the calendar if a name is provided" do
      row = ["USHol", 2020, company.name, "2020-09-18", "A new event"]
      subject.send(:process_row, row, 1, [])

      expect(Calendar.first.company_id).to eq company.id
    end

    it "returns a line error if the company cannot be found" do
      row = ["USHol", 2020, "Some other company", "2020-09-18", "A new event"]

      expect(subject.send(:process_row, row, 1, [])).to eq ["Company could not be found on line 2."]
    end

    it 'returns an error if a required field is missing' do
      row = [nil, 2020, nil, "2020-09-18", "A new event"]

      expect(subject.send(:process_row, row, 1, [])).to eq ["Required value missing on line 2."]
    end
  end

  describe 'can_view?' do
    it "allow master users on systems with feature" do
      allow(ms).to receive(:custom_feature?).with('Calendar Management').and_return true
      allow(user.company).to receive(:master?).and_return true
      expect(subject.can_view?(user)).to eq true
    end

    it "blocks non-master users on systems with feature" do
      allow(ms).to receive(:custom_feature?).with('Calendar Management').and_return true
      allow(user.company).to receive(:master?).and_return false
      expect(subject.can_view?(user)).to eq false
    end

    it "blocks master users on systems without feature" do
      allow(ms).to receive(:custom_feature?).with('Calendar Management').and_return false
      allow(user.company).to receive(:master?).and_return true
      expect(subject.can_view?(user)).to eq false
    end
  end

end
