describe OpenChain::CustomHandler::Vandegrift::VandegriftKewillCustomerActivityReportParser do

  describe "parse" do
    let (:test_data) { IO.read('spec/fixtures/files/kewill_customer_activity_report.txt') }

    it "parses file" do
      now = ActiveSupport::TimeZone['UTC'].parse('2018-03-06 16:30:12')
      Timecop.freeze(now) do
        described_class.parse test_data
      end

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['vsicilia@vandegriftinc.com']
      expect(mail.subject).to eq 'Alliance Report 300 - Customer Activity Report'
      expect(mail.body).to include "Attached is a Kewill-based report."
      expect(mail.attachments.length).to eq(1)

      attachment = mail.attachments[0]
      expect(attachment.filename).to eq("VFI_customer_activity_report_2018-03-06.xls")
      workbook = Spreadsheet.open(StringIO.new(attachment.read))
      sheet = workbook.worksheet('Data')
      expect(sheet).not_to be_nil
      expect(sheet.rows.length).to eq 7
      expect(sheet.row(0)).to eq ['Customer #', 'Name and Address', 'Mgr', 'Anyst', 'Slsmn', 'Terr', 'Add Date', 'Billing Amt', 'Revenue Amt', 'Profit%', 'Files']
      expect(sheet.row(1)).to eq ['ABCCOMP', 'ABC Company', 'X', 'Y', 'CG', 'Z', excel_date(Date.new(2003, 8, 28)), 15783.75, 355.00, 2.249, 3]
      expect(sheet.row(2)).to eq ['DEFCOMP', 'DEF Company', nil, nil, nil, nil, excel_date(Date.new(2017, 4, 12)), 10866.90, 937.50, 8.627, 11]
      expect(sheet.row(3)).to eq ['GHICOMP', 'GHI INC', nil, nil, 'BOS', nil, excel_date(Date.new(2008, 10, 17)), 7387.24, 1265.00, 17.124, 3]
      expect(sheet.row(4)).to eq ['JKLCOMP', 'JKL Enterprises', nil, nil, 'HZ', nil, excel_date(Date.new(2017, 4, 24)), 718.78, 120.00, 16.695, 1]
      expect(sheet.row(5)).to eq ['MNOCOMP', 'MNO INTERNATIONAL', nil, nil, nil, nil, excel_date(Date.new(2001, 12, 10)), -80.00, -2260.00, -2825.000, 0]
      expect(sheet.row(6)).to eq ['Grand Totals', nil, nil, nil, nil, nil, nil, 55534756.67, 2671.50, 7.686, 18]

      sheet_2 = workbook.worksheet('Parameters')
      expect(sheet_2).not_to be_nil
      expect(sheet_2.rows.length).to eq 4
      expect(sheet_2.row(0)).to eq ['VANDEGRIFT FORWARDING CO., INC.                       Customer Activity Report                     ARCSTPRS-D0-07/10/06    Page   1']
      expect(sheet_2.row(1)).to eq ['Date: 02/07/2018     Time: 08:33   Company All    From Division First to Last        Report No 300']
      expect(sheet_2.row(2)).to eq ['From Acct of Cust First to Last                   From Acct of Terr First to Last    Non-divisionalized']
      expect(sheet_2.row(3)).to eq ['Invoice Date 01/01/2018 to 01/31/2018                 Sorted By Customer             All Accounts']
    end

    # Tests a super-unlikely corner case.
    it "doesn't blow up on bogus file" do
      described_class.parse 'This single-line file is bad.'

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.attachments.length).to eq(1)
      attachment = mail.attachments[0]
      workbook = Spreadsheet.open(StringIO.new(attachment.read))
      sheet = workbook.worksheet('Data')
      expect(sheet).not_to be_nil
      expect(sheet.rows.length).to eq 1
      expect(sheet.row(0)).to eq ['Customer #', 'Name and Address', 'Mgr', 'Anyst', 'Slsmn', 'Terr', 'Add Date', 'Billing Amt', 'Revenue Amt', 'Profit%', 'Files']

      sheet_2 = workbook.worksheet('Parameters')
      expect(sheet_2).to be_nil
    end
  end

end