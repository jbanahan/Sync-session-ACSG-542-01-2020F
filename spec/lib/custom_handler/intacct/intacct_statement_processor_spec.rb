describe OpenChain::CustomHandler::Intacct::IntacctStatementProcessor do

  let (:daily_statement) {
    DailyStatement.create! pay_type: 2, statement_number: "STATEMENT", final_received_date: Date.new(2018, 3, 22), port_code: "PORT", total_amount: BigDecimal("1.23")
  }

  let (:payer) {
    instance_double(OpenChain::CustomHandler::Intacct::IntacctDailyStatementPayer)
  }

  subject {
    described_class.new statement_payer: payer
  }

  describe "run_monthly_statements" do

    let! (:monthly_daily_statement) {
      ms = MonthlyStatement.create! statement_number: "MONTHLY STATEMENT"
      daily_statement.update_attributes! pay_type: 6, monthly_statement_id: ms.id
      daily_statement
    }

    it "finds and pays daily statements on a monthly statement and reports results" do
      expect(payer).to receive(:pay_statement).with(monthly_daily_statement).and_return nil

      subject.run_monthly_statements("me@there.com")

      m = ActionMailer::Base.deliveries.first
      expect(m).not_to be_nil

      expect(m.to).to eq ["me@there.com"]
      expect(m.subject).to eq "Monthly Statements Paid #{Time.zone.now.to_date}"
      expect(m.body.raw_source).to include "Monthly Statements have been paid in Intacct."
      wb = extract_excel_from_email(m, "Monthly_Statements_Paid_#{Time.zone.now.to_date}.xls")
      expect(wb).not_to be_nil
      expect(wb.sheet_count).to eq 1
      sheet = wb.worksheet("Paid Statements")
      expect(sheet.row(0)).to eq ["Monthly Statement #", "Daily Statement #", "Total Amount", "Final Statement Date", "Port Code"]
      expect(sheet.row(1)).to eq ["MONTHLY STATEMENT", "STATEMENT", 1.23, excel_date(Date.new(2018, 3, 22)), "PORT"]

      monthly_daily_statement.reload
      expect(monthly_daily_statement.sync_records.length).to eq 1
      sr = monthly_daily_statement.sync_records.first
      expect(sr.sent_at).not_to be_nil
      expect(sr.trading_partner).to eq "Intacct"
      expect(sr.failure_message).to be_nil
    end

    it "finds and pays daily statements on a monthly statement and reports errored results" do
      errored_daily_statement = DailyStatement.create! pay_type: 6, statement_number: "ERROR STATEMENT", final_received_date: Date.new(2018,3,22), port_code: "ERROR PORT", total_amount: BigDecimal("1.99"), monthly_statement_id: monthly_daily_statement.monthly_statement_id

      expect(payer).to receive(:pay_statement).with(monthly_daily_statement).and_return nil
      expect(payer).to receive(:pay_statement).with(errored_daily_statement).and_return ["ERROR"]

      subject.run_monthly_statements("me@there.com")

      m = ActionMailer::Base.deliveries.first
      expect(m).not_to be_nil

      expect(m.to).to eq ["me@there.com"]
      expect(m.subject).to eq "Monthly Statements Paid #{Time.zone.now.to_date} With Errors"
      expect(m.body.raw_source).to include "Monthly Statements have been paid in Intacct."
      expect(m.body.raw_source).to include "Not all statements could be automatically paid. All statements listed on the 'Statement Errors' tab of the attached report must be paid manually."
      wb = extract_excel_from_email(m, "Monthly_Statements_Paid_#{Time.zone.now.to_date}.xls")
      expect(wb).not_to be_nil
      expect(wb.sheet_count).to eq 2

      sheet = wb.worksheet(0)
      expect(sheet.name).to eq "Statement Errors"
      expect(sheet.row(0)).to eq ["Monthly Statement #", "Daily Statement #", "Total Amount", "Final Statement Date", "Port Code", "Errors"]
      expect(sheet.row(1)).to eq ["MONTHLY STATEMENT", "ERROR STATEMENT", 1.99, excel_date(Date.new(2018, 3, 22)), "ERROR PORT", "ERROR"]

      sheet = wb.worksheet(1)
      expect(sheet.row(0)).to eq ["Monthly Statement #", "Daily Statement #", "Total Amount", "Final Statement Date", "Port Code"]
      expect(sheet.row(1)).to eq ["MONTHLY STATEMENT", "STATEMENT", 1.23, excel_date(Date.new(2018, 3, 22)), "PORT"]


      errored_daily_statement.reload
      expect(errored_daily_statement.sync_records.length).to eq 1
      sr = errored_daily_statement.sync_records.first
      expect(sr.sent_at).not_to be_nil
      expect(sr.trading_partner).to eq "Intacct"
      expect(sr.failure_message).to eq "ERROR"
    end

    it "skips daily statements that will appear on a monthly if the monthly statement has not been issued yet" do
      monthly_daily_statement.update_attributes! monthly_statement_id: nil

      expect(payer).not_to receive(:pay_statement).with(monthly_daily_statement)

      subject.run_monthly_statements("me@there.com")
    end

    it "skips daily statements that were finalized prior to the given start date" do
      monthly_daily_statement.update_attributes! final_received_date: Date.new(2018, 1, 1)
      expect(payer).not_to receive(:pay_statement).with(monthly_daily_statement)

      subject.run_monthly_statements("me@there.com", start_date: Date.new(2018, 3, 1))
    end

    it "picks up daily statements that were finalized after the given start date" do
      expect(payer).to receive(:pay_statement).with(monthly_daily_statement).and_return nil

      subject.run_monthly_statements("me@there.com", start_date: Date.new(2018, 3, 1))
    end
  end

  describe "run_daily_statements" do
    it "finds and pays daily statements and reports results" do
      expect(payer).to receive(:pay_statement).with(daily_statement).and_return nil

      subject.run_daily_statements("me@there.com")

      m = ActionMailer::Base.deliveries.first
      expect(m).not_to be_nil

      expect(m.to).to eq ["me@there.com"]
      expect(m.subject).to eq "Daily Statements Paid #{Time.zone.now.to_date}"
      expect(m.body.raw_source).to include "Daily Statements have been paid in Intacct."
      wb = extract_excel_from_email(m, "Daily_Statements_Paid_#{Time.zone.now.to_date}.xls")
      expect(wb).not_to be_nil
      expect(wb.sheet_count).to eq 1
      sheet = wb.worksheet("Paid Statements")
      expect(sheet.row(0)).to eq ["Daily Statement #", "Total Amount", "Final Statement Date", "Port Code"]
      expect(sheet.row(1)).to eq ["STATEMENT", 1.23, excel_date(Date.new(2018, 3, 22)), "PORT"]

      daily_statement.reload
      expect(daily_statement.sync_records.length).to eq 1
      sr = daily_statement.sync_records.first
      expect(sr.sent_at).not_to be_nil
      expect(sr.trading_partner).to eq "Intacct"
      expect(sr.failure_message).to be_nil
    end

    it "finds and pays daily statements and reports errored results" do
      errored_daily_statement = DailyStatement.create! pay_type: 2, statement_number: "ERROR STATEMENT", final_received_date: Date.new(2018, 3, 22), port_code: "ERROR PORT", total_amount: BigDecimal("1.99")

      expect(payer).to receive(:pay_statement).with(daily_statement).and_return nil
      expect(payer).to receive(:pay_statement).with(errored_daily_statement).and_return ["ERROR"]

      subject.run_daily_statements("me@there.com")

      m = ActionMailer::Base.deliveries.first
      expect(m).not_to be_nil

      expect(m.to).to eq ["me@there.com"]
      expect(m.subject).to eq "Daily Statements Paid #{Time.zone.now.to_date} With Errors"
      expect(m.body.raw_source).to include "Daily Statements have been paid in Intacct."
      expect(m.body.raw_source).to include "Not all statements could be automatically paid. All statements listed on the 'Statement Errors' tab of the attached report must be paid manually."
      wb = extract_excel_from_email(m, "Daily_Statements_Paid_#{Time.zone.now.to_date}.xls")
      expect(wb).not_to be_nil
      expect(wb.sheet_count).to eq 2

      sheet = wb.worksheet(0)
      expect(sheet.name).to eq "Statement Errors"
      expect(sheet.row(0)).to eq ["Daily Statement #", "Total Amount", "Final Statement Date", "Port Code", "Errors"]
      expect(sheet.row(1)).to eq ["ERROR STATEMENT", 1.99, excel_date(Date.new(2018, 3, 22)), "ERROR PORT", "ERROR"]

      sheet = wb.worksheet(1)
      expect(sheet.row(0)).to eq ["Daily Statement #", "Total Amount", "Final Statement Date", "Port Code"]
      expect(sheet.row(1)).to eq ["STATEMENT", 1.23, excel_date(Date.new(2018, 3, 22)), "PORT"]


      errored_daily_statement.reload
      expect(errored_daily_statement.sync_records.length).to eq 1
      sr = errored_daily_statement.sync_records.first
      expect(sr.sent_at).not_to be_nil
      expect(sr.trading_partner).to eq "Intacct"
      expect(sr.failure_message).to eq "ERROR"
    end

    it "skips daily statements that were finalized prior to the given start date" do
      daily_statement.update_attributes! final_received_date: Date.new(2018, 1, 1)
      expect(payer).not_to receive(:pay_statement).with(daily_statement)

      subject.run_daily_statements("me@there.com", start_date: Date.new(2018, 3, 1))
    end

    it "picks up daily statements that were finalized after the given start date" do
      expect(payer).to receive(:pay_statement).with(daily_statement).and_return nil

      subject.run_daily_statements("me@there.com", start_date: Date.new(2018, 3, 1))
    end
  end

  describe "run_schedulable" do
    subject { described_class }

    it "runs monthly statements" do
      expect_any_instance_of(subject).to receive(:run_monthly_statements).with "me@there.com", start_date: nil

      subject.run_schedulable({"monthly" => true, "email_to" => "me@there.com"})
    end

    it "runs daily statements" do
      expect_any_instance_of(subject).to receive(:run_daily_statements).with "me@there.com", start_date: nil

      subject.run_schedulable({"daily" => true, "email_to" => "me@there.com"})
    end

    it "utilizes given start date" do
      expect_any_instance_of(subject).to receive(:run_daily_statements).with "me@there.com", start_date: Date.new(2018, 4, 1)

      subject.run_schedulable({"daily" => true, "email_to" => "me@there.com", "start_date" => '2018-4-1'})
    end

    it "errors if start date is invalid" do
      expect {subject.run_schedulable({"daily" => true, "email_to" => "me@there.com", "start_date" => "notadate"})}.to raise_error "Invalid 'start_date' value of 'notadate'."
    end

    it "errors if email_to opt is missing" do
      expect {subject.run_schedulable({"daily" => true})}.to raise_error "At least one email recipient must be configured."
    end

    it "errors if daily/monthly key is missing" do
      expect {subject.run_schedulable({"email_to" => "me@there.com"})}.to raise_error "A 'daily' or 'monthly' configuration value must be present."
    end
  end
end