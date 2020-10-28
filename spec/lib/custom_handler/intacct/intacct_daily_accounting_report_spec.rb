describe OpenChain::CustomHandler::Intacct::IntacctDailyAccountingReport do

  let! (:export) do
    IntacctAllianceExport.create! file_number: "2529468", suffix: "A", export_type: IntacctAllianceExport::EXPORT_TYPE_INVOICE, shipment_customer_number: "SHIPCUST",
                                  customer_number: "CUST", ap_total: BigDecimal("1.23"), ar_total: BigDecimal("10.99"), invoice_date: Date.new(2020, 5, 1), division: "11",
                                  shipment_number: "SHIPNO", broker_reference: "BROKREF"
  end

  let! (:receivable) do
    r = export.intacct_receivables.create! invoice_number: "2529468A", currency: "USD", invoice_date: Date.new(2020, 5, 1),
                                           shipment_customer_number: "SHIPCUST", customer_number: "CUST"
    r.intacct_receivable_lines.create! vendor_number: "VENDOR", vendor_reference: "VEN REF", charge_code: "999", charge_description: "DESC", amount: BigDecimal("10.99"),
                                       broker_file: "BROK"
    r
  end

  let! (:payable) do
    p = export.intacct_payables.create! bill_number: "2529468A", vendor_number: "VENDOR", vendor_reference: "VEN REF", currency: "USD",
                                        bill_date: Date.new(2020, 5, 1), shipment_customer_number: "SHIPCUST"
    p.intacct_payable_lines.create! charge_code: "123", charge_description: "DESC", amount: BigDecimal("1.23")
    p
  end

  describe "build_report" do
    it "generates a report" do
      report_data = StringIO.new
      subject.build_report(Date.new(2020, 5, 1), Date.new(2020, 5, 1), {}) do |date_range_description, tempfile|
        expect(date_range_description).to eq "05/01/2020"
        report_data.write tempfile.read
      end
      report_data.rewind
      spreadsheet = xlsx_data(report_data)

      expect(spreadsheet["Daily Billing Summary"]).not_to be_blank
      rows = spreadsheet["Daily Billing Summary"]
      expect(rows[0]).to eq ["File #", "Broker Reference", "Invoice Number", "Division", "Invoice Date", "Customer",
                             "Bill To", "AR Total", "AP Total", "Profit / Loss"]
      expect(rows[1]).to eq ["SHIPNO", "BROKREF", "2529468A", "11", Date.new(2020, 5, 1), "SHIPCUST", "CUST",
                             BigDecimal("10.99"), BigDecimal("1.23"), BigDecimal("9.76")]
      expect(rows[2]).to eq [nil, nil, nil, nil, nil, nil, nil, "SUBTOTAL(9, H2:H2)", "SUBTOTAL(9, I2:I2)", "SUBTOTAL(9, J2:J2)"]

      expect(spreadsheet["AR Details"]).not_to be_blank
      rows = spreadsheet["AR Details"]
      expect(rows[0]).to eq ["Invoice Number", "Division", "Invoice Date", "Customer", "Bill To", "Currency", "Charge Code", "Charge Description", "Charge Amount"]
      expect(rows[1]).to eq ["2529468A", "11", Date.new(2020, 5, 1), "SHIPCUST", "CUST", "USD", "999", "DESC", BigDecimal("10.99")]

      expect(spreadsheet["AP Details"]).not_to be_blank
      rows = spreadsheet["AP Details"]
      expect(rows[0]).to eq ["Invoice Number", "Division", "Invoice Date", "Customer", "Bill To", "Currency", "Vendor", "Vendor Reference",
                             "Charge Code", "Charge Description", "Charge Amount"]
      expect(rows[1]).to eq ["2529468A", "11", Date.new(2020, 5, 1), "SHIPCUST", "CUST", "USD", "VENDOR", "VEN REF", "123", "DESC", 1.23]
    end

    it "does not return invoices outside date range" do
      # The end_date uses a < value, not a <= so the following line should drop off the
      export.update! invoice_date: Date.new(2020, 5, 2)
      report_data = StringIO.new
      subject.build_report(Date.new(2020, 5, 1), Date.new(2020, 5, 1), {}) do |date_range_description, tempfile|
        expect(date_range_description).to eq "05/01/2020"
        report_data.write tempfile.read
      end
      report_data.rewind
      spreadsheet = xlsx_data(report_data)

      expect(spreadsheet["Daily Billing Summary"]).not_to be_blank
      rows = spreadsheet["Daily Billing Summary"]
      expect(rows[0]).to eq ["File #", "Broker Reference", "Invoice Number", "Division", "Invoice Date", "Customer",
                             "Bill To", "AR Total", "AP Total", "Profit / Loss"]
      expect(rows[1]).to eq ["No accounting data found for 05/01/2020."]
    end

    it "skips non-invoice exports" do
      export.update! export_type: "check"

      report_data = StringIO.new
      subject.build_report(Date.new(2020, 5, 1), Date.new(2020, 5, 1), {}) do |date_range_description, tempfile|
        expect(date_range_description).to eq "05/01/2020"
        report_data.write tempfile.read
      end
      report_data.rewind
      spreadsheet = xlsx_data(report_data)

      expect(spreadsheet["Daily Billing Summary"]).not_to be_blank
      rows = spreadsheet["Daily Billing Summary"]
      expect(rows[1]).to eq ["No accounting data found for 05/01/2020."]
    end

    it "skips Freight invoices when line of business is given as Brokerage" do
      export.update! division: "11"

      report_data = StringIO.new
      subject.build_report(Date.new(2020, 5, 1), Date.new(2020, 5, 1), {"line_of_business" => "brokerage"}) do |date_range_description, tempfile|
        expect(date_range_description).to eq "05/01/2020"
        report_data.write tempfile.read
      end
      report_data.rewind
      spreadsheet = xlsx_data(report_data)
      expect(spreadsheet["Daily Billing Summary"][1]).to eq ["No accounting data found for 05/01/2020."]
    end

    it "skips Brokerage invoices when line of business is given as Freight" do
      export.update! division: "1"

      report_data = StringIO.new
      subject.build_report(Date.new(2020, 5, 1), Date.new(2020, 5, 1), {"line_of_business" => "freight"}) do |date_range_description, tempfile|
        expect(date_range_description).to eq "05/01/2020"
        report_data.write tempfile.read
      end
      report_data.rewind
      spreadsheet = xlsx_data(report_data)
      expect(spreadsheet["Daily Billing Summary"][1]).to eq ["No accounting data found for 05/01/2020."]
    end
  end

  describe "run_schedulable" do

    subject { described_class }

    def extract_spreadsheet mail
      attachment = mail.attachments.first
      expect(attachment).not_to be_nil
      xlsx_data(StringIO.new(attachment.read))
    end

    it "generates a report" do
      subject.run_schedulable({"email" => "me@there.com", "start_date" => "2020-05-01", "end_date" => "2020-05-01"})

      # THe build_report tests test everyting about actually building the report, so just test the assembling of the params
      # and the emailing here
      expect(ActionMailer::Base.deliveries.size).to eq 1
      email = ActionMailer::Base.deliveries.first
      spreadsheet = extract_spreadsheet(email)

      expect(spreadsheet["Daily Billing Summary"]).not_to be_blank
      rows = spreadsheet["Daily Billing Summary"]
      expect(rows[1]).to eq ["SHIPNO", "BROKREF", "2529468A", "11", Date.new(2020, 5, 1), "SHIPCUST", "CUST", BigDecimal("10.99"), BigDecimal("1.23"), BigDecimal("9.76")]

      expect(email.to).to eq ["me@there.com"]
      expect(email.subject).to eq "Daily Accounting Report 05/01/2020"
      expect(email.body.raw_source).to include "Attached is the Daily Accounting Report for 05/01/2020."
      expect(email.attachments["Daily Accounting Report 05-01-2020.xlsx"]).not_to be_nil
    end

    it "uses given date range" do
      subject.run_schedulable({"email" => "me@there.com", "start_date" => "2020-05-01", "end_date" => "2020-05-03"})

      expect(ActionMailer::Base.deliveries.size).to eq 1
      email = ActionMailer::Base.deliveries.first
      expect(email.subject).to eq "Daily Accounting Report 05/01/2020 - 05/03/2020"
      expect(email.attachments["Daily Accounting Report 05-01-2020 - 05-03-2020.xlsx"]).not_to be_nil
      expect(email.body.raw_source).to include "Attached is the Daily Accounting Report for 05/01/2020 - 05/03/2020."
    end

    it "does not return invoices outside date range" do
      # The end_date uses a < value, not a <= so the following line should drop off the
      export.update! invoice_date: Date.new(2020, 5, 2)
      subject.run_schedulable({"email" => "me@there.com", "start_date" => "2020-05-01", "end_date" => "2020-05-01"})

      expect(ActionMailer::Base.deliveries.size).to eq 1
      email = ActionMailer::Base.deliveries.first
      expect(email.subject).to eq "Daily Accounting Report 05/01/2020"

      spreadsheet = extract_spreadsheet(email)
      expect(spreadsheet["Daily Billing Summary"]).not_to be_blank
      rows = spreadsheet["Daily Billing Summary"]
      expect(rows[0]).to eq ["File #", "Broker Reference", "Invoice Number", "Division", "Invoice Date", "Customer", "Bill To", "AR Total", "AP Total", "Profit / Loss"]
      expect(rows[1]).to eq ["No accounting data found for 05/01/2020."]
    end
  end

  describe "run_report" do
    let (:now) { Time.zone.parse("2020-05-03 03:00") }
    let (:user) { User.new time_zone: "America/New_York" }

    it "runs report using user settings" do
      # This test is using a parameter that calculates the start / end date off the user's timezone, which
      # helps us prove that the run_by is utilized correctly
      report_data = StringIO.new
      Timecop.freeze(now) do
        subject.run_report(user, {"previous_day" => 1}) do |tempfile|
          report_data.write tempfile.read
        end
      end

      report_data.rewind

      spreadsheet = xlsx_data(report_data)

      # Run report uses build_report under the covers, which is thoroughly test cased so, just verify some data is
      # loaded
      expect(spreadsheet["Daily Billing Summary"]).not_to be_blank
      rows = spreadsheet["Daily Billing Summary"]
      expect(rows[1]).to eq ["SHIPNO", "BROKREF", "2529468A", "11", Date.new(2020, 5, 1), "SHIPCUST", "CUST", BigDecimal("10.99"), BigDecimal("1.23"), BigDecimal("9.76")]
    end
  end

  describe "permission?" do

    subject { described_class }

    let (:user) { User.new }
    let! (:ms) { stub_master_setup }

    it "allows intacct accounting group users in WWW system" do
      allow(ms).to receive(:custom_feature?).with("WWW").and_return true
      allow(user).to receive(:in_group?).with("intacct-accounting").and_return true

      expect(subject.permission?(user)).to eq true
    end
  end
end