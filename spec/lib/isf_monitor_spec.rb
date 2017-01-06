require 'spec_helper'

RSpec.describe 'ISF Monitor' do
  let(:ls_output) {
    ["-rw-------   1 user group         3471 Dec 30 08:57 VAND0323_EDI_LUMBER6690558_20161230085703.xml",
          "-rw-------   1 user group         3471 Dec 30 08:56 VAND0323_EDI_LUMBER6690558_20161230085703.xml",
          "-rw-------   1 user group         3471 Dec 30 08:58 VAND0323_EDI_LUMBER6690558_20161230085703.xml"]
  }

  describe '#parse_ftp_dates' do
    it 'returns just the times' do
      expect(OpenChain::IsfMonitor.new.parse_ftp_dates(ls_output)).to eql(['08:57', '08:56', '08:58'])
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
  describe '#est_dates_to_utc_dates' do
    it 'converts the est dates to utc dates and returns an array' do
      date1 = Time.zone.parse("08:56").utc
      date2 = Time.zone.parse("08:57").utc
      date3 = Time.zone.parse("08:58").utc
      expected = [date1.utc, date2.utc, date3.utc]
      dates = [date1, date2, date3]

      expect(OpenChain::IsfMonitor.new.est_dates_to_utc_dates(dates)).to eql(expected)
    end
  end

  describe '#ftp_dates_to_est' do
    it 'converts the ftp times to eastern time' do
      date1 = Time.use_zone("Eastern Time (US & Canada)") { Time.zone.parse("08:57") }
      date2 = Time.use_zone("Eastern Time (US & Canada)") { Time.zone.parse("08:56") }
      date3 = Time.use_zone("Eastern Time (US & Canada)") { Time.zone.parse("O8:58") }

      times = OpenChain::IsfMonitor.new.parse_ftp_dates(ls_output)
      expect(OpenChain::IsfMonitor.new.ftp_dates_to_est(times)).to eql([date1, date2, date3])
    end
  end
end