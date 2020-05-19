describe OpenChain::CustomHandler::LumberLiquidators::LumberInvoiceReport do

  let (:entry) do
    entry = Factory(:entry)
    c1 = entry.containers.create! container_number: "12345"
    c2 = entry.containers.create! container_number: "98765"

    invoice = Factory(:commercial_invoice, entry: entry)
    line1 = Factory(:commercial_invoice_line, commercial_invoice: invoice, container: c1, po_number: "PO1", prorated_mpf: 25, hmf: 10, cotton_fee: 5)
    Factory(:commercial_invoice_tariff, commercial_invoice_line: line1, entered_value: 100, duty_amount: 50, gross_weight: 100)
    Factory(:commercial_invoice_tariff, hts_code: "99038815", commercial_invoice_line: line1, entered_value: 100, duty_amount: 50, gross_weight: 20)

    line2 = Factory(:commercial_invoice_line, commercial_invoice: invoice, container: c2, po_number: "PO2", add_duty_amount: 25, cvd_duty_amount: 75)
    Factory(:commercial_invoice_tariff, commercial_invoice_line: line2, entered_value: 100, duty_amount: 50, gross_weight: 50)

    entry.reload
  end

  let (:invoice) do
    invoice = Factory(:broker_invoice, entry: entry, invoice_number: "INV123", invoice_date: Date.new(2016, 3, 1), customer_number: "LUMBER", source_system: "Alliance")
    Factory(:broker_invoice_line, broker_invoice: invoice, charge_code: "0001", charge_amount: 290)
    Factory(:broker_invoice_line, broker_invoice: invoice, charge_code: "0004", charge_amount: 99.99)
    Factory(:broker_invoice_line, broker_invoice: invoice, charge_code: "0005", charge_amount: 150)

    invoice.reload
  end

  let (:synced_invoice) do
    sync_invoice(invoice, Date.new(2016, 3, 1))
    invoice
  end

  let (:invoice_2) do
    invoice = Factory(:broker_invoice, entry: entry, invoice_number: "INV123A", invoice_date: Date.new(2016, 3, 2), customer_number: "LUMBER", source_system: "Alliance")
    Factory(:broker_invoice_line, broker_invoice: invoice, charge_code: "0001", charge_amount: -150)

    invoice.reload
  end

  def sync_invoice inv, sent_at
    if inv.entry.sync_records.find {|sr| sr.trading_partner == OpenChain::CustomHandler::LumberLiquidators::LumberCostingReport.sync_code }.nil?
      inv.entry.sync_records.create! trading_partner: OpenChain::CustomHandler::LumberLiquidators::LumberCostingReport.sync_code, sent_at: sent_at
    end
    inv.sync_records.create! trading_partner: OpenChain::CustomHandler::LumberLiquidators::LumberCostingReport.sync_code, sent_at: sent_at
  end

  before do
    stub_master_setup
  end

  describe "generate_report" do
    it "creates xls file with invoice data" do
      now = Time.zone.now
      wb = subject.generate_report [invoice, invoice_2], now
      # Just expect that the worksheet has a summary page in it, we know we're using a module to generate
      # that, and the module is tested elsewhere
      expect(wb.worksheet("Summary")).not_to be_nil

      sheet = wb.worksheet "Details"

      expect(sheet.row(0)).to eq ["VFI Invoice Number", "Invoice Date", "Invoice Total", "PO Number", "Container Number", "Ocean Freight", "Duty",
                                  "Additional Duty", "ADD/CVD", "Fees", "PO Total"]
      expect(sheet.row(1)).to eq [Spreadsheet::Link.new(invoice.entry.excel_url, "INV123"), Date.new(2016, 3, 1), 539.99, "PO1", "12345", 50.0, 90.0, 50.0, 0.0, 100.0, 290.0]
      expect(sheet.row(2)).to eq ["", "", "", "PO2", "98765", 49.99, 50.0, 0.0, 100.0, 50.0, 249.99]

      # What this is testing is that we're prorating the duty amounts IF the duty amount listed on the broker invoice is not the same as the amount
      # on the actual entry (.ie cases where we back out duty amounts or the original billed amount was wrong).
      # We're also testing the proration on negative amounts (which has some slight nuance to handling it)
      expect(sheet.row(3)).to eq [Spreadsheet::Link.new(invoice_2.entry.excel_url, "INV123A"), Date.new(2016, 3, 2), -150.0, "PO1", "12345", 0.0, -48.28, -17.24, -34.48, 0.0, -100.0] # rubocop:disable Layout/LineLength
      expect(sheet.row(4)).to eq ["", "", "", "PO2", "98765", 0.0, -24.14, -8.62, -17.24, 0.0, -50.0]
      expect(sheet.row(5)).to eq []
      expect(sheet.row(6)).to eq ["GRAND TOTAL", "", 389.99]
    end
  end

  describe "generate_and_send_report" do
    let (:workbook) { XlsMaker.create_workbook "Test", ["Header"] }

    it "generates a report and emails it" do
      # Just mock out the method that generates the report, it's tested above
      expect(subject).to receive(:generate_report).with([invoice], Date.new(2016, 3, 1)).and_return workbook

      subject.generate_and_send_report [invoice], Date.new(2016, 3, 1), email_to: ["me@there.com"]

      invoice.reload
      expect(invoice.sync_records.length).to eq 1
      sr = invoice.sync_records.first
      expect(sr.trading_partner).to eq "LL BILLING"
      expect(sr.sent_at).to be_within(1.minute).of(Time.zone.now)
      expect(sr.confirmed_at).to be_within(2.minutes).of(Time.zone.now)

      expect(ActionMailer::Base.deliveries.length).to eq 1
      m = ActionMailer::Base.deliveries.first
      expect(m.to).to eq ["me@there.com"]
      expect(m.bcc).to eq ["payments@vandegriftinc.com"]
      expect(m.subject).to eq "Vandegrift, Inc. Billing for Mar 01, 2016"
      expect(m.body.raw_source).to include "Attached is the Vandegrift weekly invoice file."
      wb = Spreadsheet.open(StringIO.new(m.attachments["VFI Weekly Invoice 2016-03-01.xls"].read))
      expect(wb.worksheet("Test")).not_to be_nil
    end
  end

  describe "find_invoices" do

    before do
      synced_invoice
    end

    it "finds invoices that are before given date and have no sync_records" do
      invoices = subject.find_invoices Date.new(2016, 3, 1), Date.new(2016, 3, 2)
      expect(invoices.length).to eq 1
      expect(invoices.first).to eq invoice
    end

    it "finds invoices that have been synced but have sent_at blanked" do
      invoice.sync_records.create! trading_partner: "LL BILLING"

      invoices = subject.find_invoices Date.new(2016, 3, 1), Date.new(2016, 3, 2)
      expect(invoices.length).to eq 1
      expect(invoices.first).to eq invoice
    end

    it "does not find synced invoices" do
      invoice.sync_records.create! trading_partner: "LL BILLING", sent_at: Time.zone.now
      expect(subject.find_invoices(Date.new(2016, 3, 1), Date.new(2016, 3, 2)).length).to eq 0
    end

    it "does not find invoices sent on cost file after given date" do
      synced_invoice.sync_records.first.update! sent_at: Date.new(2016, 3, 2)
      expect(subject.find_invoices(Date.new(2016, 3, 1), Date.new(2016, 3, 2)).length).to eq 0
    end

    it "does not find invoices sent on cost file before given date" do
      synced_invoice.sync_records.first.update! sent_at: Date.new(2016, 2, 29)
      expect(subject.find_invoices(Date.new(2016, 3, 1), Date.new(2016, 3, 2)).length).to eq 0
    end

    it "returns invoices ordered by invoice date" do
      invoice_2.update! invoice_date: Date.new(2016, 1, 1)
      invoice_2.sync_records.create! trading_partner: OpenChain::CustomHandler::LumberLiquidators::LumberCostingReport.sync_code, sent_at: Date.new(2016, 3, 1)
      invoices = subject.find_invoices Date.new(2016, 3, 1), Date.new(2016, 3, 2)
      expect(invoices.length).to eq 2
      expect(invoices.first).to eq invoice_2
      expect(invoices.second).to eq invoice
    end

    context "with supplemental invoice" do

      before do
        # clear out the cost report invoice sync (use synced_invoice since it creates all the behind the scenes stuff for us)
        synced_invoice.sync_records.find {|sr| sr.trading_partner == OpenChain::CustomHandler::LumberLiquidators::LumberCostingReport.sync_code}.destroy
      end

      it "includes invoices that were included on a supplemental invoice feed during the given report timeframe" do
        synced_invoice.sync_records.create! trading_partner: OpenChain::CustomHandler::LumberLiquidators::LumberSupplementalInvoiceSender.sync_code,
                                            sent_at: Date.new(2016, 3, 1)
        invoices = subject.find_invoices Date.new(2016, 3, 1), Date.new(2016, 3, 2)

        expect(invoices.length).to eq 1
        expect(invoices.first).to eq synced_invoice
      end

      it "does not include invoices with supplemental invoices sent outside the reporting period" do
        synced_invoice.sync_records.create! trading_partner: OpenChain::CustomHandler::LumberLiquidators::LumberSupplementalInvoiceSender.sync_code,
                                            sent_at: Date.new(2016, 3, 3)
        invoices = subject.find_invoices Date.new(2016, 3, 1), Date.new(2016, 3, 2)
        expect(invoices.length).to eq 0
      end
    end

    it "includes invoices on same entry with one being costing report and the other supplemental" do
      invoice_2.sync_records.create! trading_partner: OpenChain::CustomHandler::LumberLiquidators::LumberSupplementalInvoiceSender.sync_code,
                                     sent_at: Date.new(2016, 3, 2)
      invoices = subject.find_invoices Date.new(2016, 3, 1), Date.new(2016, 3, 3)

      expect(invoices.length).to eq 2
      expect(invoices.first).to eq synced_invoice
      expect(invoices.second).to eq invoice_2
    end

    it "ignores invoices that were not sent on an entry's costing report" do
      # Just creating the second invoice withtout the sync record means it should not appear on the report
      invoice_2

      invoices = subject.find_invoices Date.new(2016, 3, 1), Date.new(2016, 3, 2)
      expect(invoices.length).to eq 1
      expect(invoices.first).to eq invoice
    end
  end

  describe "run_schedulable" do
    it "runs report for current time" do
      # Make sure run_scheduled is using the current time by making the entry's sync record by making the sync record be at the extreme
      # edge of the run window
      synced_invoice

      # Run schedulable uses a date range of the previous workweek (Monday - Sunday), so set the entry up so that based
      # soley on the time of the sync it apperas to be off the report, but adjusting for the timezone change it will be on the report.
      synced_invoice.sync_records.first.update! sent_at: ActiveSupport::TimeZone["UTC"].parse("2016-04-11 03:59")

      Timecop.freeze(DateTime.new(2016, 4, 16, 4, 0)) do
        described_class.run_schedulable({"email_to" => ["me@there.com"]})
      end

      invoice.reload
      expect(invoice.sync_records.length).to eq 2
      expect(invoice.sync_records.find {|sr| sr.trading_partner == "LL BILLING" }).not_to be_nil

      expect(ActionMailer::Base.deliveries.length).to eq 1
      m = ActionMailer::Base.deliveries.first
      expect(m.to).to eq ["me@there.com"]
    end
  end
end
