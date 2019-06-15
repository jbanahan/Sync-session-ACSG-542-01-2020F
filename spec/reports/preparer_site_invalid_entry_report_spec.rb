describe OpenChain::Report::PreparerSiteInvalidEntryReport do
  let(:start_date) { (Time.zone.now).beginning_of_day.in_time_zone("America/New_York")  }
  let(:end_date) { (Time.zone.now).end_of_day.in_time_zone("America/New_York") }

  def get_emailed_worksheet sheet_name, file_name, mail = ActionMailer::Base.deliveries.pop
    fail("Expected at least one mail message.") unless mail
    at = mail.attachments[file_name]
    expect(at).not_to be_nil
    wb = Spreadsheet.open(StringIO.new(at.read))
    wb.worksheets.find {|s| s.name == sheet_name}
  end

  describe '.get_start_date' do
    it 'returns 1/1/2018 if current date is before 7/1/2018' do
      Timecop.freeze(Time.zone.parse("15/03/2018").beginning_of_day) do
        expect(described_class.get_start_date).to eql(Time.zone.parse("01/01/2018").beginning_of_day)
      end
    end

    it 'returns current date - 6 months if date is 7/1/2018 or greater' do
      Timecop.freeze(Time.zone.parse("01/07/2018").beginning_of_day) do
        expect(described_class.get_start_date).to eql((Time.zone.now - 6.months).beginning_of_day)
      end
    end
  end

  describe '.run_schedulable' do
    it 'handles passed in dates' do
      emails = "bbommarito@vandegriftinc.com\ntest@vandegriftinc.com"
      klass = described_class.new
      allow(described_class).to receive(:new).and_return(klass)

      Timecop.freeze(Time.zone.now) do
        start_day = "03/12/2016"
        end_day = "03/12/2016"
        start_date = Time.zone.parse(start_day).beginning_of_day.in_time_zone("America/New_York")
        end_date = Time.zone.parse(end_day).end_of_day.in_time_zone("America/New_York")

        expect(klass).to receive(:run).with(["bbommarito@vandegriftinc.com", "test@vandegriftinc.com"], start_date, end_date)
        described_class.run_schedulable({'email_to' => emails, 'start_date' => start_day, 'end_date' => end_day})
      end
    end

    it "defaults to calculated start date " do
      emails = "bbommarito@vandegriftinc.com\ntest@vandegriftinc.com"
      klass = described_class.new
      allow(described_class).to receive(:new).and_return(klass)

      Timecop.freeze(Time.zone.now) do
        start_date = described_class.get_start_date.beginning_of_day.in_time_zone("America/New_York")
        end_date = (Time.zone.now).end_of_day.in_time_zone("America/New_York")

        expect(klass).to receive(:run).with(["bbommarito@vandegriftinc.com", "test@vandegriftinc.com"], start_date, end_date)
        described_class.run_schedulable({'email_to' => emails})
      end
    end
  end

  describe 'run' do
    before do
      @entry = Factory.create(:entry)
      @port = Port.create(:name=>'PORT', :schedule_d_code=>"1234")
      @entry.update_attributes(
          last_exported_from_source: start_date,
          entry_filed_date: start_date,
          release_date: start_date,
          file_logged_date: start_date,
          broker_reference: 'BROKER',
          release_cert_message: 'CERT MESSAGE',
          entry_port_code: @port.schedule_d_code,
          source_system: 'Alliance'
      )
      @entry.entry_comments << EntryComment.create!(body: 'STMNT PREPARER SITE INVALID' )
    end

    it 'ignores fixed entries' do
      @entry.entry_comments << EntryComment.create!(body: 'SUMMARY HAS BEEN ADDED' )

      described_class.new.run ['bbommarito@vandegriftinc.com'], start_date, end_date

      Timecop.freeze(Time.zone.now) do
        sheet = get_emailed_worksheet 'Statement Preparer Site Invalid', "Statement Preparer Site Invalid - #{Time.zone.now.to_date}.xls"

        expect(sheet).to_not be_nil
        expect(sheet.row(0)).to eq ['Broker Reference', 'Entry Filed Date', 'Release Date', 'Release Certification Message', 'Port Code', 'Port Name', 'User Notes']
        expect(sheet.row(1)).to eq ['No invalid statement preparer sites']
      end
    end

    it 'handles more than one failure' do
      second_entry = Factory.create(:entry)
      second_entry.update_attributes(
          last_exported_from_source: start_date,
          entry_filed_date: start_date,
          release_date: start_date,
          file_logged_date: start_date,
          broker_reference: 'BROKER1',
          release_cert_message: 'CERT MESSAGE',
          entry_port_code: @port.schedule_d_code,
          source_system: 'Alliance'
      )
      second_entry.entry_comments << EntryComment.create!(body: 'STMNT PREPARER SITE INVALID', created_at: 5.minutes.ago )

      described_class.new.run ['bbommarito@vandegriftinc.com'], start_date, end_date

      Timecop.freeze(Time.zone.now) do
        sheet = get_emailed_worksheet 'Statement Preparer Site Invalid', "Statement Preparer Site Invalid - #{Time.zone.now.to_date}.xls"

        expect(sheet).to_not be_nil
        expect(sheet.row(0)).to eq ['Broker Reference', 'Entry Filed Date', 'Release Date', 'Release Certification Message', 'Port Code', 'Port Name', 'User Notes']
        expect(sheet.row(1)).to eq ['BROKER', excel_date(end_date.to_date), excel_date(end_date.to_date), 'CERT MESSAGE', '1234', 'PORT', 'STMNT PREPARER SITE INVALID']
        expect(sheet.row(2)).to eq ['BROKER1', excel_date(end_date.to_date), excel_date(end_date.to_date), 'CERT MESSAGE', '1234', 'PORT', 'STMNT PREPARER SITE INVALID']
      end
    end

    it 'handles the most insane possible case' do
      @entry.entry_comments << EntryComment.create!(body: "SUMMARY HAS BEEN ADDED", created_at: Time.zone.now)
      @entry.entry_comments << EntryComment.create!(body: 'STMNT PREPARER SITE INVALID', created_at: Time.zone.now + 1.second)
      @entry.entry_comments << EntryComment.create!(body: "SUMMARY HAS BEEN ADDED", created_at: Time.zone.now + 2.seconds)
      # We want the final 'failure' to be somewhat unique
      @entry.entry_comments << EntryComment.create!(body: 'STMNT PREPARER SITE INVALID 1234', created_at: Time.zone.now + 3.seconds)

      described_class.new.run ['bbommarito@vandegriftinc.com'], start_date, end_date

      Timecop.freeze(Time.zone.now) do
        sheet = get_emailed_worksheet 'Statement Preparer Site Invalid', "Statement Preparer Site Invalid - #{Time.zone.now.to_date}.xls"

        expect(sheet).to_not be_nil
        expect(sheet.row(0)).to eq ['Broker Reference', 'Entry Filed Date', 'Release Date', 'Release Certification Message', 'Port Code', 'Port Name', 'User Notes']
        expect(sheet.row(1)).to eq ['BROKER', excel_date(end_date.to_date), excel_date(end_date.to_date), 'CERT MESSAGE', '1234', 'PORT', 'STMNT PREPARER SITE INVALID 1234']
      end
    end

    it 'identifies entries that have a preparer site invalid error' do
      described_class.new.run ['bbommarito@vandegriftinc.com'], start_date, end_date

      Timecop.freeze(Time.zone.now) do
        sheet = get_emailed_worksheet 'Statement Preparer Site Invalid', "Statement Preparer Site Invalid - #{Time.zone.now.to_date}.xls"

        expect(sheet).to_not be_nil
        expect(sheet.row(0)).to eq ['Broker Reference', 'Entry Filed Date', 'Release Date', 'Release Certification Message', 'Port Code', 'Port Name', 'User Notes']
        expect(sheet.row(1)).to eq ['BROKER', excel_date(end_date.to_date), excel_date(end_date.to_date), 'CERT MESSAGE', '1234', 'PORT', 'STMNT PREPARER SITE INVALID']
      end
    end

    it 'does not find entries that do not have the proper note' do
      comment = EntryComment.first
      comment.body = 'THIS IS NOT A VALID NOTE'
      comment.save!

      Timecop.freeze(Time.zone.now) do
        described_class.new.run ["bbommarito@vandegriftinc.com"], start_date, end_date

        sheet = get_emailed_worksheet 'Statement Preparer Site Invalid', "Statement Preparer Site Invalid - #{Time.zone.now.to_date}.xls"

        expect(sheet).to_not be_nil
        expect(sheet.row(1)).to eq ["No invalid statement preparer sites"]
      end
    end

    it 'does not find entries that are outside the given dates' do
      @entry.update_attributes(last_exported_from_source: 4.days.from_now)
      @entry.reload
      described_class.new.run ["bbommarito@vandegriftinc.com"], start_date, end_date

      Timecop.freeze(Time.zone.now) do
        sheet = get_emailed_worksheet 'Statement Preparer Site Invalid', "Statement Preparer Site Invalid - #{Time.zone.now.to_date}.xls"

        expect(sheet).to_not be_nil
        expect(sheet.row(1)).to eq ["No invalid statement preparer sites"]
      end
    end
  end
end
