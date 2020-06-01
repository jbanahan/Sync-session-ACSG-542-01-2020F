describe OpenChain::CustomHandler::Intacct::IntacctDailyAccountingReport do

  describe "run_schedulable" do
    let! (:export) do
      IntacctAllianceExport.create! file_number: "2529468", suffix: "A", export_type: IntacctAllianceExport::EXPORT_TYPE_INVOICE, customer_number: "CUST",
                                    ap_total: BigDecimal("1.23"), ar_total: BigDecimal("10.99"), invoice_date: Date.new(2020, 5, 1), division: "11"
    end

    let! (:receivable) do
      r = export.intacct_receivables.create! invoice_number: "2529468A", currency: "USD", invoice_date: Date.new(2020, 5, 1), customer_number: "CUST"
      r.intacct_receivable_lines.create! vendor_number: "VENDOR", vendor_reference: "VEN REF", charge_code: "999", charge_description: "DESC", amount: BigDecimal("10.99")
      r
    end

    let! (:payable) do
      p = export.intacct_payables.create! bill_number: "2529468A", vendor_number: "VENDOR", vendor_reference: "VEN REF", currency: "USD",
                                          bill_date: Date.new(2020, 5, 1), customer_number: "CUST"
      p.intacct_payable_lines.create! charge_code: "123", charge_description: "DESC", amount: BigDecimal("1.23")
      p
    end

    def extract_spreadsheet mail
      attachment = mail.attachments.first
      expect(attachment).not_to be_nil
      xlsx_data(StringIO.new(attachment.read))
    end

    it "generates a report using yesterday's date" do
      now = Time.zone.parse("2020-05-02 04:00")
      Timecop.freeze(now) { subject.run({"email" => "me@there.com"}) }

      expect(ActionMailer::Base.deliveries.size).to eq 1
      email = ActionMailer::Base.deliveries.first
      spreadsheet = extract_spreadsheet(email)

      expect(spreadsheet["Daily Billing Summary"]).not_to be_blank
      rows = spreadsheet["Daily Billing Summary"]
      expect(rows[0]).to eq ["Invoice Number", "Division", "Invoice Date", "Customer", "AR Total", "AP Total", "Profit / Loss"]
      expect(rows[1]).to eq ["2529468A", "11", Date.new(2020, 5, 1), "CUST", BigDecimal("10.99"), BigDecimal("1.23"), BigDecimal("9.76")]
      expect(rows[2]).to eq [nil, nil, nil, nil, "SUBTOTAL(9, E2:E2)", "SUBTOTAL(9, F2:F2)", "SUBTOTAL(9, G2:G2)"]

      expect(spreadsheet["AR Details"]).not_to be_blank
      rows = spreadsheet["AR Details"]
      expect(rows[0]).to eq ["Invoice Number", "Division", "Invoice Date", "Customer", "Currency", "Vendor",
                             "Vendor Reference", "Charge Code", "Charge Description", "Charge Amount"]
      expect(rows[1]).to eq ["2529468A", "11", Date.new(2020, 5, 1), "CUST", "USD", "VENDOR", "VEN REF", "999", "DESC", BigDecimal("10.99")]

      expect(spreadsheet["AP Details"]).not_to be_blank
      rows = spreadsheet["AP Details"]
      expect(rows[0]).to eq ["Invoice Number", "Division", "Invoice Date", "Customer", "Currency", "Vendor", "Vendor Reference",
                             "Charge Code", "Charge Description", "Charge Amount"]
      expect(rows[1]).to eq ["2529468A", "11", Date.new(2020, 5, 1), "CUST", "USD", "VENDOR", "VEN REF", "123", "DESC", 1.23]

      expect(email.to).to eq ["me@there.com"]
      expect(email.subject).to eq "Daily Accounting Report 05/01/2020"
      expect(email.body.raw_source).to include "Attached is the Daily Accounting Report for 05/01/2020."
      expect(email.attachments["Daily Accounting Report 05-01-2020.xlsx"]).not_to be_nil
    end

    it "uses given date range" do
      subject.run({"email" => "me@there.com", "start_date" => "2020-05-01", "end_date" => "2020-05-03"})

      expect(ActionMailer::Base.deliveries.size).to eq 1
      email = ActionMailer::Base.deliveries.first
      expect(email.subject).to eq "Daily Accounting Report 05/01/2020 - 05/03/2020"
      expect(email.attachments["Daily Accounting Report 05-01-2020 - 05-03-2020.xlsx"]).not_to be_nil
      expect(email.body.raw_source).to include "Attached is the Daily Accounting Report for 05/01/2020 - 05/03/2020."
    end

    it "does not return invoices outside date range" do
      # The end_date uses a < value, not a <= so the following line should drop off the
      export.update! invoice_date: Date.new(2020, 5, 2)
      now = Time.zone.parse("2020-05-02 04:00")
      Timecop.freeze(now) { subject.run({"email" => "me@there.com"}) }

      expect(ActionMailer::Base.deliveries.size).to eq 1
      email = ActionMailer::Base.deliveries.first
      expect(email.subject).to eq "Daily Accounting Report 05/01/2020"

      spreadsheet = extract_spreadsheet(email)
      expect(spreadsheet["Daily Billing Summary"]).not_to be_blank
      rows = spreadsheet["Daily Billing Summary"]
      expect(rows[0]).to eq ["Invoice Number", "Division", "Invoice Date", "Customer", "AR Total", "AP Total", "Profit / Loss"]
      expect(rows[1]).to eq ["No accounting data found for 05/01/2020."]
    end
  end
end