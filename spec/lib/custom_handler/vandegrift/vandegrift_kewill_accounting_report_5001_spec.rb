describe OpenChain::CustomHandler::Vandegrift::VandegriftKewillAccountingReport5001 do

  describe "parse" do
    let (:test_data) { IO.read('spec/fixtures/files/kewill_account_report_5001.txt')}

    it "parses file" do
      now = ActiveSupport::TimeZone['UTC'].parse('2018/03/21 06:01:00')
      Timecop.freeze(now) do
        described_class.parse test_data
      end

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['vsicilia@vandegriftinc.com']
      expect(mail.subject).to eq 'Alliance Report 5001 - ARPRFSUB'
      expect(mail.body).to include "Attached is a Kewill-based report."
      expect(mail.attachments.length).to eq(1)

      attachment = mail.attachments[0]
      expect(attachment.filename).to eq("ARPRFSUB_2018-03-21.xls")
      workbook = Spreadsheet.open(StringIO.new(attachment.read))
      sheet = workbook.worksheet('Data')
      expect(sheet).to_not be_nil
      expect(sheet.rows.length).to eq 29
      expect(sheet.row(0)).to eq ['File Number', 'Master Bill', 'Div', 'Inv Date', 'Open A/R', 'Open A/P', 'Total A/R-', 'Total A/P=', 'Profit', 'Bill To']
      expect(sheet.row(28)).to eq ['Grand Totals', nil, nil, nil, 3011.0, 22199.81, 3011.0, 5058.0, -2047.0]

      sheet_2 = workbook.worksheet('Parameters')
      expect(sheet_2).to_not be_nil
      expect(sheet_2.rows.length).to eq 7
      expect(sheet_2.row(0)).to eq ['VANDEGRIFT FORWARDING CO., INC.                       luca 2018                                    ARPRFSUM-D0-07/31/07    Page  35']
      expect(sheet_2.row(1)).to eq ['Date: 03/15/2018     Time: 12:14   Company All    From Division First to Last        Report No 5001']
      expect(sheet_2.row(2)).to eq ['From Acct of Cust FIRST to LAST                   From File No First to Last         Do NOT Consolidate Masters']
      expect(sheet_2.row(3)).to eq ['From AWB/BL # First to Last                       Sorted By Customer                 Currency USD']
      expect(sheet_2.row(4)).to eq ['From Dest Country First to Last      Invoice Date 03/01/2018 to 03/15/2018           All Accounts']
      expect(sheet_2.row(5)).to eq ['From Exprt Country First to Last     From Acct of Terr First to Last                 NOT Negative Profit Only']
      expect(sheet_2.row(6)).to eq ['Include DD,Over/Under Pay            Non-divisionalized                              Exclude Blank Customers']
    end

    it "doesn't blow up on bogus file" do
      described_class.parse 'This single-line file is bad.'

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.attachments.length).to eq(1)
      attachment = mail.attachments[0]
      workbook = Spreadsheet.open(StringIO.new(attachment.read))
      sheet = workbook.worksheet('Data')
      expect(sheet).not_to be_nil
      expect(sheet.rows.length).to eq 2
      expect(sheet.row(0)).to eq ['File Number', 'Master Bill', 'Div', 'Inv Date', 'Open A/R', 'Open A/P', 'Total A/R-', 'Total A/P=', 'Profit', 'Bill To']
      expect(sheet.row(1)).to eq ['Grand Totals', nil, nil, nil, 0, 0, 0, 0, 0]

      sheet_2 = workbook.worksheet('Parameters')
      expect(sheet_2).to be_nil
    end
  end
end
