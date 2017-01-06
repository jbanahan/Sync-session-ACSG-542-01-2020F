require 'spec_helper'
require 'net/ftp'

RSpec.describe 'ISF Monitor' do
  let!(:ftp_files) { ["file1.txt", "file2.txt", "file3.txt"] }
  let!(:ftp_dates) { [16.minutes.ago.utc, 15.minutes.ago.utc, 5.minutes.ago.utc] }
  let!(:ftp) { Net::FTP.new }

  before do
    allow(Net::FTP).to receive(:new).and_return(ftp)
  end

  describe '#process_ftp_conents' do
    it 'returns the dates of the files' do
      dates = ftp_dates.dup
      ftp_files.each do |file|
        expect(ftp).to receive(:mtime).with(file).and_return(dates.shift)
      end

      expect(OpenChain::IsfMonitor.new.process_ftp_contents(ftp, ftp_files)).to eql(ftp_dates)
    end
  end

  describe '#is_backed_up?' do
    it 'considers the ftp backed up if oldest date is before current date' do
      future_date = 10.minutes.from_now.utc

      expect(OpenChain::IsfMonitor.new.is_backed_up?(future_date, 15)).to be true
    end

    it 'considers the ftp backed up if oldest date is older than now - 15 minutes' do
      past_date = 16.minutes.ago.utc

      expect(OpenChain::IsfMonitor.new.is_backed_up?(past_date, 15)).to be true
    end
  end

  describe '#utc_to_est_date' do
    it 'converts the passed in date to an est date' do
      expect(OpenChain::IsfMonitor.new.utc_to_est_date(ftp_dates[0])).
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

      expect(OpenChain::IsfMonitor.new.sort_utc_dates(dates)).to eql(expected)
    end
  end
end