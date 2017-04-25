describe OpenChain::CustomHandler::Ascena::AscenaEntryIsfMismatchReport do


  describe "run_report" do
    let (:importer) { Factory(:importer) }
    let! (:entry) {
      e = Factory(:entry, importer: importer, broker_reference: "REF", entry_number: "ENT", master_bills_of_lading: "MBOL", container_numbers: "CONT", transport_mode_code: "10", first_entry_sent_date: ActiveSupport::TimeZone["UTC"].parse("2017-05-01 12:00"))
      i = e.commercial_invoices.create! invoice_number: "INV"
      l = i.commercial_invoice_lines.create! po_number: "PO", part_number: "PART", country_origin_code: "CO"
      t = l.commercial_invoice_tariffs.create! hts_code: "1234567890"

      e
    }

    let! (:isf) {
      sf = Factory(:security_filing, importer: importer, transaction_number: "TRANS", entry_reference_numbers: "REF", master_bill_of_lading: "MBOL")
      sf.security_filing_lines.create! po_number: "PO", part_number: "PART", hts_code: "1234567890", country_of_origin_code: "CO"

      sf
    }

    let (:tz) {
      ActiveSupport::TimeZone["UTC"]
    }

    it "reports nothing if entry matches isf by reference number" do
      file = subject.run_report importer, tz.parse("2017-03-01 07:00"), tz.parse("2017-03-01 12:30")
      wb = XlsMaker.open_workbook file
      sheet = wb.worksheet "Entry / ISF Match"
      expect(sheet).not_to be_nil
      expect(sheet.rows.length).to eq 1
      expect(sheet.row(0)).to eq ["Transaction Number", "Master Bill", "Container Number", "Entry Number", "Country of Origin Code (ISF)", "Country of Origin Code (Entry)", "PO Number (ISF)", "PO Number (Entry)", "Part Number (ISF)", "Part Number (Entry)", "HTS Code (ISF)", "HTS Code (Entry)", "ISF Match", "HTS Match", "COO Match", "PO Match", "Style Match"]
    end

    it "reports nothing if entry matches isf by master bill" do
      isf.update_attributes! entry_reference_numbers: "NO MATCH"

      file = subject.run_report importer, tz.parse("2017-05-01 07:00"), tz.parse("2017-05-01 12:30")
      wb = XlsMaker.open_workbook file
      sheet = wb.worksheet "Entry / ISF Match"
      expect(sheet.rows.length).to eq 1
    end

    it "reports if entry does not match to an isf" do
      isf.update_attributes! entry_reference_numbers: "NO MATCH", master_bill_of_lading: "NO MATCH"

      file = subject.run_report importer, tz.parse("2017-05-01 07:00"), tz.parse("2017-05-01 12:30")
      wb = XlsMaker.open_workbook file
      sheet = wb.worksheet "Entry / ISF Match"
      expect(sheet.rows.length).to eq 2

      expect(sheet.row(1)).to eq [nil, "MBOL", "CONT", "ENT", nil, nil, nil, nil, nil, nil, nil, nil, "N", "N", "N", "N", "N" ]
    end

    it "reports if entry does not match to country origin" do
      isf.security_filing_lines.first.update_attributes! country_of_origin_code: "ISF"

      file = subject.run_report importer, tz.parse("2017-05-01 07:00"), tz.parse("2017-05-01 12:30")
      wb = XlsMaker.open_workbook file
      sheet = wb.worksheet "Entry / ISF Match"
      expect(sheet.rows.length).to eq 2

      expect(sheet.row(1)).to eq ["TRANS", "MBOL", "CONT", "ENT", "ISF", "CO", "PO", "PO", "PART", "PART", "1234.56.7890", "1234.56.7890", "Y", "Y", "N", "Y", "Y"]
    end

    it "reports if entry does not match to PO" do
      isf.security_filing_lines.first.update_attributes! po_number: "ISF"

      file = subject.run_report importer, tz.parse("2017-05-01 07:00"), tz.parse("2017-05-01 12:30")
      wb = XlsMaker.open_workbook file
      sheet = wb.worksheet "Entry / ISF Match"
      expect(sheet.rows.length).to eq 2

      expect(sheet.row(1)).to eq ["TRANS", "MBOL", "CONT", "ENT", "CO", "CO", "ISF", "PO", "PART", "PART", "1234.56.7890", "1234.56.7890", "Y", "Y", "Y", "N", "Y"]
    end

    it "reports if entry does not match to Part" do
      isf.security_filing_lines.first.update_attributes! part_number: "ISF"

      file = subject.run_report importer, tz.parse("2017-05-01 07:00"), tz.parse("2017-05-01 12:30")
      wb = XlsMaker.open_workbook file
      sheet = wb.worksheet "Entry / ISF Match"
      expect(sheet.rows.length).to eq 2

      expect(sheet.row(1)).to eq ["TRANS", "MBOL", "CONT", "ENT", "CO", "CO", "PO", "PO", "ISF", "PART", "1234.56.7890", "1234.56.7890", "Y", "Y", "Y", "Y", "N"]
    end

    it "reports if entry does not match to HTS" do
      isf.security_filing_lines.first.update_attributes! hts_code: "1234578906"

      file = subject.run_report importer, tz.parse("2017-05-01 07:00"), tz.parse("2017-05-01 12:30")
      wb = XlsMaker.open_workbook file
      sheet = wb.worksheet "Entry / ISF Match"
      expect(sheet.rows.length).to eq 2

      expect(sheet.row(1)).to eq ["TRANS", "MBOL", "CONT", "ENT", "CO", "CO", "PO", "PO", "PART", "PART", "1234.57.8906", "1234.56.7890", "Y", "N", "Y", "Y", "Y"]
    end

    it "does not report if hts matches first 6 digits, but doesn't match the rest of the digits" do
      isf.security_filing_lines.first.update_attributes! hts_code: "1234561234"

      file = subject.run_report importer, tz.parse("2017-05-01 07:00"), tz.parse("2017-05-01 12:30")
      wb = XlsMaker.open_workbook file
      sheet = wb.worksheet "Entry / ISF Match"
      expect(sheet.rows.length).to eq 1
    end

    it "does not report entries that are not non-Ocean transport modes" do
      entry.update_attributes! transport_mode_code: "40"
      isf.security_filing_lines.first.update_attributes! po_number: "ISF"

      file = subject.run_report importer, tz.parse("2017-05-01 07:00"), tz.parse("2017-05-01 12:30")
      wb = XlsMaker.open_workbook file
      sheet = wb.worksheet "Entry / ISF Match"
      expect(sheet.rows.length).to eq 1
    end

    it "does not report entries that are outside the time range" do
      entry.update_attributes! first_entry_sent_date: tz.parse("2017-05-01 12:31")

      file = subject.run_report importer, tz.parse("2017-05-01 07:00"), tz.parse("2017-05-01 12:30")
      wb = XlsMaker.open_workbook file
      sheet = wb.worksheet "Entry / ISF Match"
      expect(sheet.rows.length).to eq 1
    end

    it "does not report entries prior to 4/21/2017" do
      entry.update_attributes! first_entry_sent_date: tz.parse("2017-04-20 00:00")

      file = subject.run_report importer, tz.parse("2017-04-01 07:00"), tz.parse("2017-05-01 12:30")
      wb = XlsMaker.open_workbook file
      sheet = wb.worksheet "Entry / ISF Match"
      expect(sheet.rows.length).to eq 1
    end
  end


  describe "run_schedulable" do

    let (:tempfile) {
      t = Tempfile.new ["file", ".txt"]
      Attachment.add_original_filename_method t, "file.txt"
      t
    }

    let! (:ascena) { Factory(:importer, alliance_customer_number: "ASCE")}

    after (:each) { tempfile.close! }

    it "runs and emails report over previous and next week" do
      now = Time.zone.now

      expected_start = now.in_time_zone("America/New_York").midnight - 7.days
      expected_end = now.in_time_zone("America/New_York").midnight + 7.days

      expect_any_instance_of(described_class).to receive(:run_report).with(ascena, expected_start, expected_end).and_return tempfile

      Timecop.freeze(now) do 
        described_class.run_schedulable({"email" => ["me@there.com"]})
      end

      expect(ActionMailer::Base.deliveries.size).to eq 1

      m = ActionMailer::Base.deliveries.first
      expect(m.to).to eq ["me@there.com"]
      expect(m.subject).to eq "Ascena Entry/ISF Mismatch #{expected_start.to_date} - #{expected_end.to_date}"
      expect(m.body).to include "The Entry/ISF Mismatch report for Entry Summary Sent Dates between #{expected_start.to_date} - #{expected_end.to_date} is attached."
    end
  end
end