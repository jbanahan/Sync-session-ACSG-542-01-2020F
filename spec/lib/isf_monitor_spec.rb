require 'net/ftp'

describe OpenChain::IsfMonitor do
  let!(:ftp_files) { ["file1.txt", "file2.txt", "file3.txt"] }
  let!(:ftp_dates) { [16.minutes.ago.utc, 15.minutes.ago.utc, 5.minutes.ago.utc] }
  let!(:ftp) { instance_double(Net::FTP) }

  before do
    allow(subject).to receive(:ftp_client).and_return ftp
  end

  describe '#fake_utc_to_utc' do
    it 'creates an ACTUAL UTC date' do
      expect(subject.fake_utc_to_utc(Time.new(2017, 3, 1, 14, 59, 59), "America/New_York")).
        to eq ActiveSupport::TimeZone["UTC"].parse("2017-03-01 19:59:59")
    end
  end

  describe '#process_ftp_conents' do
    it 'returns the dates of the files' do
      dates = ftp_dates.dup
      corrected_dates = dates.map { |date| ActiveSupport::TimeZone["America/New_York"].parse(date.strftime("%Y-%m-%d %H:%M:%S.%N")).utc }
      ftp_files.each do |file|
        expect(ftp).to receive(:mtime).with(file).and_return(dates.shift)
      end

      expect(subject.process_ftp_contents(ftp, ftp_files, "America/New_York")).to eql(corrected_dates)
    end
  end

  describe '#is_backed_up?' do
    it 'considers the ftp backed up if oldest date is older than now - 15 minutes' do
      past_date = 16.minutes.ago.utc

      expect(subject.is_backed_up?(past_date, 15)).to be true
    end
  end

  describe '#utc_to_est_date' do
    it 'converts the passed in date to an est date' do
      expect(subject.utc_to_est_date(ftp_dates[0])).
          to eql(ftp_dates[0].in_time_zone("America/New_York"))
    end
  end

  describe '#sort_utc_dates' do
    it 'sorts an array of dates oldest date first' do
      date1 = Time.zone.parse("08:56").utc
      date2 = Time.zone.parse("08:57").utc
      date3 = Time.zone.parse("08:58").utc
      dates = [date2, date3, date1]
      expected = [date1, date2, date3]

      expect(subject.sort_utc_dates(dates)).to eql(expected)
    end
  end

  describe "run" do

    let (:company) {
      create(:company)
    }

    let (:user) {
      create(:user, company: company)
    }

    it "finds backed up files and reports them" do
      expect(subject).to receive(:find_backed_up_files).with("hostname", "username", "password", "directory", 15, "America/New_York").and_return({oldest_file_date: Time.zone.now, directory_list: ["File 1", "File 2"], file_count: 2})
      subject.run("hostname", "username", "password", "directory", 15, "America/New_York")

      m = ActionMailer::Base.deliveries.first
      expect(m).not_to be_nil
      expect(m.to).to eq ["support@vandegriftinc.com"]
      expect(m.subject).to eq "ISF Processing Stuck"
      expect(m.body).to include "Kewill EDI ISF processing is delayed"
    end

    it "uses mailist list" do
      list = MailingList.create! user_id: user.id, company_id: company.id, system_code: "ISF Monitor", name: "ISF Monitor", email_addresses: "me@there.com"

      expect(subject).to receive(:find_backed_up_files).with("hostname", "username", "password", "directory", 15, "America/New_York").and_return({oldest_file_date: Time.zone.now, directory_list: ["File 1", "File 2"], file_count: 2})
      subject.run("hostname", "username", "password", "directory", 15, "America/New_York")

      m = ActionMailer::Base.deliveries.first
      expect(m).not_to be_nil
      expect(m.to).to eq ["me@there.com"]
    end
  end
end