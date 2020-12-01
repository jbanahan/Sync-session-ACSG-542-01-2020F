describe OpenChain::CustomHandler::Burlington::BurlingtonBillingReport do

  describe "run_schedulable" do
    it "calls the actual run method" do
      settings = {'email' => 'a@b.com'}
      expect(described_class).to receive(:new).and_return subject
      expect(subject).to receive(:run_report).with(settings)

      described_class.run_schedulable(settings)
    end
  end

  describe "run_report" do
    it "raises an exception if blank email param is provided" do
      expect(subject).not_to receive(:generate_report)

      expect { subject.run_report({'email' => ' '}) }.to raise_error("At least one email address must be present under the 'email' key.")
    end

    it "raises an exception if no email param is provided" do
      expect(subject).not_to receive(:generate_report)

      expect { subject.run_report({}) }.to raise_error("At least one email address must be present under the 'email' key.")
    end

    it "generates and emails spreadsheet" do
      entry_1 = FactoryBot(:entry, entry_number: "entry-cb-1", source_system: "Alliance", po_numbers: "A\n B",
                                destination_state: "NJ", entry_filed_date: Date.new(2018, 12, 23),
                                container_numbers: "C\n D", broker_invoice_total: BigDecimal("18.12"))
      # This first invoice falls outside the date window for this report.
      bi_1a = entry_1.broker_invoices.create! customer_number: "BURLI", invoice_number: "bi_1a", invoice_date: Date.new(2019, 9, 22)
      bi_1a.broker_invoice_lines.create! charge_code: "0007", charge_description: "CUSTOMS ENTRY", charge_amount: BigDecimal("5")
      # The next two invoices are within the window.
      bi_1b = entry_1.broker_invoices.create! customer_number: "BURLI", invoice_number: "bi_1b", invoice_date: Date.new(2019, 9, 23)
      bi_1b.broker_invoice_lines.create! charge_code: "0026", charge_description: "FOOD & DRUG PROCESSING", charge_amount: BigDecimal("3.21")
      bi_1b.broker_invoice_lines.create! charge_code: "0007", charge_description: "CUSTOMS ENTRY", charge_amount: BigDecimal("6")
      bi_1c = entry_1.broker_invoices.create! customer_number: "BURLI", invoice_number: "bi_1c", invoice_date: Date.new(2019, 9, 29)
      bi_1c.broker_invoice_lines.create! charge_code: "0125", charge_description: "FISH & WILDLIFE CHARGES", charge_amount: BigDecimal("2.13")
      bi_1c.broker_invoice_lines.create! charge_code: "0026", charge_description: "FOOD & DRUG PROCESSING", charge_amount: BigDecimal(".24")
      # This final invoice has an invoice date of today, which is not included in the date range.
      bi_1d = entry_1.broker_invoices.create! customer_number: "BURLI", invoice_number: "bi_1d", invoice_date: Date.new(2019, 9, 30)
      bi_1d.broker_invoice_lines.create! charge_code: "0125", charge_description: "FISH & WILDLIFE CHARGES", charge_amount: BigDecimal("2.17")

      entry_2 = FactoryBot(:entry, entry_number: "entry-ab-2", source_system: "Alliance", po_numbers: "C",
                                destination_state: "CA", entry_filed_date: Date.new(2018, 12, 24),
                                container_numbers: "E", broker_invoice_total: BigDecimal("19.13"))
      bi_2 = entry_2.broker_invoices.create! customer_number: "BURLI", invoice_number: "bi_2", invoice_date: Date.new(2019, 9, 25)
      bi_2.broker_invoice_lines.create! charge_code: "0007", charge_description: "CUSTOMS ENTRY", charge_amount: BigDecimal("4.54")
      bi_2.broker_invoice_lines.create! charge_code: "0026", charge_description: "FOOD & DRUG PROCESSING", charge_amount: BigDecimal("3.72")
      bi_2.broker_invoice_lines.create! charge_code: "0095", charge_description: "FILING PROTEST", charge_amount: BigDecimal("20.02")
      bi_2.broker_invoice_lines.create! charge_code: "0095", charge_description: "FILING PROTEST", charge_amount: BigDecimal(".03")
      # All of the charges that follow should be ignored due to the charge codes used.
      bi_2.broker_invoice_lines.create! charge_code: "0001", charge_description: "DUTY", charge_amount: BigDecimal("1")
      bi_2.broker_invoice_lines.create! charge_code: "0014", charge_description: "OVERNIGHT DELIVERY CHARGE", charge_amount: BigDecimal("1")
      bi_2.broker_invoice_lines.create! charge_code: "0082", charge_description: "ADVANCE OF FUNDS", charge_amount: BigDecimal("1")
      bi_2.broker_invoice_lines.create! charge_code: "0099", charge_description: "DUTY PD DIRECT", charge_amount: BigDecimal("1")
      bi_2.broker_invoice_lines.create! charge_code: "0720", charge_description: "PIER PASS", charge_amount: BigDecimal("1")
      bi_2.broker_invoice_lines.create! charge_code: "0739", charge_description: "PIER PASS CHARGE", charge_amount: BigDecimal("1")

      # This broker invoice should be excluded because its source system is not Alliance.
      entry_3 = FactoryBot(:entry, entry_number: "entry-ef-3", source_system: "Axis", po_numbers: "D",
                                destination_state: "MO", entry_filed_date: Date.new(2018, 12, 25),
                                container_numbers: "F", broker_invoice_total: BigDecimal("20.14"))
      bi_3 = entry_3.broker_invoices.create! customer_number: "BURLI", invoice_number: "bi_3", invoice_date: Date.new(2019, 9, 26)
      bi_3.broker_invoice_lines.create! charge_code: "0007", charge_description: "CUSTOMS ENTRY", charge_amount: BigDecimal("4.54")

      # This entry isn't Burlington's.  Excluded, obviously.
      entry_4 = FactoryBot(:entry, entry_number: "entry-gh-4", source_system: "Alliance", po_numbers: "E",
                                destination_state: "MI", entry_filed_date: Date.new(2018, 12, 26),
                                container_numbers: "G", broker_invoice_total: BigDecimal("21.15"))
      bi_4 = entry_4.broker_invoices.create! customer_number: "HURLI", invoice_number: "bi_4", invoice_date: Date.new(2019, 9, 26)
      bi_4.broker_invoice_lines.create! charge_code: "0007", charge_description: "CUSTOMS ENTRY", charge_amount: BigDecimal("4.54")

      # Although this invoice's only charge is in the "ignored" category, the entry should still appear on the report.
      entry_5 = FactoryBot(:entry, entry_number: "entry-ij-5", source_system: "Alliance", po_numbers: "F",
                                destination_state: "NV", entry_filed_date: Date.new(2018, 12, 27),
                                container_numbers: "H", broker_invoice_total: BigDecimal("22.16"))
      bi_5 = entry_5.broker_invoices.create! customer_number: "BURLI", invoice_number: "bi_5", invoice_date: Date.new(2019, 9, 24)
      bi_5.broker_invoice_lines.create! charge_code: "0001", charge_description: "DUTY", charge_amount: BigDecimal("1")

      Timecop.freeze(make_eastern_date(2019, 9, 30)) do
        subject.run_report({ 'email' => 'a@b.com', 'cc' => 'b@c.com', 'bcc' => 'c@d.com' })
      end

      expect(ActionMailer::Base.deliveries.length).to eq 1
      mail = ActionMailer::Base.deliveries.first
      expect(mail.to).to eq ["a@b.com"]
      expect(mail.cc).to eq ["b@c.com"]
      expect(mail.bcc).to eq ["c@d.com"]
      expect(mail.subject).to eq "Burlington Weekly Billing Report"
      expect(mail.body).to include "Attached is the Burlington Weekly Billing Report."

      att = mail.attachments["Burlington_Weekly_Billing_Report_20190930.xlsx"]
      expect(att).not_to be_nil
      reader = XlsxTestReader.new(StringIO.new(att.read)).raw_workbook_data
      expect(reader.length).to eq 1

      sheet = reader["Data"]
      expect(sheet).not_to be_nil
      expect(sheet.length).to eq 15
      expect(sheet[0]).to eq ["Vandegrift Forwarding Company"]
      expect(sheet[1]).to eq ["100 Walnut Avenue"]
      expect(sheet[2]).to eq ["Suite 600"]
      expect(sheet[3]).to eq ["Clark, NJ 07066"]
      expect(sheet[4]).to eq []
      expect(sheet[5]).to eq ["BURLINGTON MANIFEST DATE: 09/30/2019"]
      expect(sheet[6]).to eq ["Invoice / Manifest Number: Bur20190930"]
      expect(sheet[7]).to eq []
      expect(sheet[8]).to eq ["Entry Number", "PO Numbers", "Destination State", "Entry Filed Date", "Container Numbers",
                              "CUSTOMS ENTRY", "FILING PROTEST", "FISH & WILDLIFE CHARGES", "FOOD & DRUG PROCESSING",
                              "Total Broker Invoice"]
      expect(sheet[9]).to eq ["entry-ab-2", "C", "CA", Date.new(2018, 12, 24), "E", 4.54, 20.05, 0, 3.72, 19.13]
      expect(sheet[10]).to eq ["entry-cb-1", "A", "NJ", Date.new(2018, 12, 23), "C,D", 6.0, 0, 0, 3.21, 18.12]
      expect(sheet[11]).to eq [nil, "B", "NJ", Date.new(2018, 12, 23), nil, nil, nil, nil, nil, nil]
      expect(sheet[12]).to eq ["entry-cb-1", "A", "NJ", Date.new(2018, 12, 23), "C,D", 0, 0, 2.13, 0.24, 18.12]
      expect(sheet[13]).to eq [nil, "B", "NJ", Date.new(2018, 12, 23), nil, nil, nil, nil, nil, nil]
      expect(sheet[14]).to eq ["entry-ij-5", "F", "NV", Date.new(2018, 12, 27), "H", 0, 0, 0, 0, 22.16]
    end

    it "uses custom date range when provided" do
      entry_1 = FactoryBot(:entry, entry_number: "entry-cb-1", source_system: "Alliance", po_numbers: "A",
                                destination_state: "NJ", entry_filed_date: Date.new(2018, 12, 23),
                                container_numbers: "C\n D", broker_invoice_total: BigDecimal("18.12"))
      # This invoice date is outside the default range.  If it's included in the output, it means that the report is
      # using the custom date range being passed to it.
      bi_1 = entry_1.broker_invoices.create! customer_number: "BURLI", invoice_number: "bi_1", invoice_date: Date.new(2019, 9, 1)
      bi_1.broker_invoice_lines.create! charge_code: "0007", charge_description: "CUSTOMS ENTRY", charge_amount: BigDecimal("5")

      Timecop.freeze(make_eastern_date(2019, 9, 30)) do
        subject.run_report({ 'email' => 'a@b.com', 'start_date' => '2019-08-30', 'end_date' => '2019-09-05' })
      end

      expect(ActionMailer::Base.deliveries.length).to eq 1
      mail = ActionMailer::Base.deliveries.first
      att = mail.attachments["Burlington_Weekly_Billing_Report_20190930.xlsx"]
      reader = XlsxTestReader.new(StringIO.new(att.read)).raw_workbook_data
      sheet = reader["Data"]
      expect(sheet.length).to eq 10
      expect(sheet[8]).to eq ["Entry Number", "PO Numbers", "Destination State", "Entry Filed Date", "Container Numbers",
                              "CUSTOMS ENTRY", "Total Broker Invoice"]
      expect(sheet[9]).to eq ["entry-cb-1", "A", "NJ", Date.new(2018, 12, 23), "C,D", 5.0, 18.12]
    end

    def make_utc_date year, month, day
      ActiveSupport::TimeZone["UTC"].parse("#{year}-#{month}-#{day} 16:00")
    end

    def make_eastern_date year, month, day
      dt = make_utc_date(year, month, day)
      dt = dt.in_time_zone(ActiveSupport::TimeZone["America/New_York"])
      dt
    end
  end

end