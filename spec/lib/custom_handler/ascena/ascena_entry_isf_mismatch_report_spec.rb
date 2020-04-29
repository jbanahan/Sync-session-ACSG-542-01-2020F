describe OpenChain::CustomHandler::Ascena::AscenaEntryIsfMismatchReport do


  describe "run_report" do
    let (:importer) { Factory(:importer) }
    let! (:entry) {
      e = Factory(:entry, importer: importer, broker_reference: "REF", entry_number: "ENT", master_bills_of_lading: "MBOL", house_bills_of_lading: "HBOL\n HBOL2", container_numbers: "CONT", transport_mode_code: "10", first_entry_sent_date: ActiveSupport::TimeZone["UTC"].parse("2017-05-01 12:00"))
      i = e.commercial_invoices.create! invoice_number: "INV"
      l = i.commercial_invoice_lines.create! po_number: "PO", part_number: "PART", country_origin_code: "CO", product_line: "BRAND"
      t = l.commercial_invoice_tariffs.create! hts_code: "1234567890"

      e
    }

    let! (:isf) {
      sf = Factory(:security_filing, importer: importer, transaction_number: "TRANS", entry_reference_numbers: "REF", master_bill_of_lading: "MBOL", house_bills_of_lading: "HBOL1")
      sf.security_filing_lines.create! po_number: "PO", part_number: "PART", hts_code: "1234567890", country_of_origin_code: "CO"

      sf
    }

    let (:tz) {
      ActiveSupport::TimeZone["UTC"]
    }

    it "reports nothing if entry matches isf by reference number" do
      file = subject.run_report importer, tz.parse("2017-03-01 07:00"), tz.parse("2017-03-01 12:30")
      reader = XlsxTestReader.new(file.path).raw_workbook_data
      sheet = reader["Entry ISF Match"]
      expect(sheet).not_to be_nil
      expect(sheet.count).to eq 1
      expect(sheet[0]).to eq ["ISF Transaction Number", "Master Bill", "House Bills", "Broker Reference", "Brand", "PO Number (Entry)", "PO Number (ISF)", "Part Number (Entry)", "Part Number (ISF)", "Country of Origin Code (Entry)", "Country of Origin Code (ISF)", "HTS Code 1 (Entry)", "", "HTS Code (ascena Verified)", "", "ascena Match?", "HTS Code 2 (Entry)", "HTS Code 3 (Entry)", "HTS Code (ISF)", "ISF Match", "PO Match", "Part Number Match", "COO Match", "HTS Match", "Exception Description", "ascena Comment", "Date"]
    end

    it "reports nothing if entry matches isf by master bill" do
      isf.update_attributes! entry_reference_numbers: "NO MATCH"

      file = subject.run_report importer, tz.parse("2017-05-01 07:00"), tz.parse("2017-05-01 12:30")
      reader = XlsxTestReader.new(file.path).raw_workbook_data
      sheet = reader["Entry ISF Match"]
      expect(sheet.count).to eq 1
    end

    it "reports if entry does not match to an isf" do
      isf.update_attributes! entry_reference_numbers: "NO MATCH", master_bill_of_lading: "NO MATCH"

      file = subject.run_report importer, tz.parse("2017-05-01 07:00"), tz.parse("2017-05-01 12:30")
      reader = XlsxTestReader.new(file.path).raw_workbook_data
      sheet = reader["Entry ISF Match"]
      expect(sheet.count).to eq 2

      expect(sheet[1]).to eq ["", "MBOL", "HBOL, HBOL2", "REF", nil, nil, nil, nil, nil, nil, nil, "", nil, nil, nil, nil, "", "", "", "N", "N", "N", "N", "N", "Unabled to find an ISF with a Broker Reference of 'REF' OR a Master Bill of 'MBOL' OR a House Bill in 'HBOL, HBOL2'."]
    end

    it "reports if entry matches to an isf, but the isf doesn't have any lines" do
      isf.security_filing_lines.destroy_all

      file = subject.run_report importer, tz.parse("2017-05-01 07:00"), tz.parse("2017-05-01 12:30")
      reader = XlsxTestReader.new(file.path).raw_workbook_data
      sheet = reader["Entry ISF Match"]
      expect(sheet.count).to eq 2

      expect(sheet[1]).to eq ["", "MBOL", "HBOL, HBOL2", "REF", nil, nil, nil, nil, nil, nil, nil, "", nil, nil, nil, nil, "", "", "", "N", "N", "N", "N", "N", "Unabled to find an ISF with a Broker Reference of 'REF' OR a Master Bill of 'MBOL' OR a House Bill in 'HBOL, HBOL2'."]
    end

    it "reports if entry does not match to country origin" do
      isf.security_filing_lines.first.update_attributes! country_of_origin_code: "ISF"

      file = subject.run_report importer, tz.parse("2017-05-01 07:00"), tz.parse("2017-05-01 12:30")
      reader = XlsxTestReader.new(file.path).raw_workbook_data
      sheet = reader["Entry ISF Match"]
      expect(sheet.count).to eq 2

      expect(sheet[1]).to eq ["TRANS", "MBOL", "HBOL1", "REF", "BRAND", "PO", "PO", "PART", "PART", "CO", "ISF", "1234.56.7890", nil, nil, nil, nil, "", "", "1234.56.7890", "Y", "Y", "Y", "N", "Y", "The ISF line with PO # 'PO' and Part 'PART' did not match to Country 'CO'."]
    end

    it "reports if entry does not match to PO" do
      isf.security_filing_lines.first.update_attributes! po_number: "ISF"

      file = subject.run_report importer, tz.parse("2017-05-01 07:00"), tz.parse("2017-05-01 12:30")
      reader = XlsxTestReader.new(file.path).raw_workbook_data
      sheet = reader["Entry ISF Match"]
      expect(sheet.count).to eq 2

      expect(sheet[1]).to eq ["TRANS", "MBOL", "HBOL1", "REF", "BRAND", "PO", "", "PART", nil, "CO", "", "1234.56.7890", nil, nil, nil, nil, "", "", "", "Y", "N", "N", "N", "N", "Unable to find PO # 'PO' on ISF 'TRANS'."]
    end

    it "reports if entry does not match to Part" do
      isf.security_filing_lines.first.update_attributes! part_number: "ISF"

      file = subject.run_report importer, tz.parse("2017-05-01 07:00"), tz.parse("2017-05-01 12:30")
      reader = XlsxTestReader.new(file.path).raw_workbook_data
      sheet = reader["Entry ISF Match"]
      expect(sheet.count).to eq 2

      expect(sheet[1]).to eq ["TRANS", "MBOL", "HBOL1", "REF", "BRAND", "PO", "PO", "PART", nil, "CO", "", "1234.56.7890", nil, nil, nil, nil, "", "", "", "Y", "Y", "N", "N", "N", "Unable to find an ISF line with PO # 'PO' and Part # 'PART' on ISF 'TRANS'."]
    end

    it "reports if entry does not match to HTS" do
      isf.security_filing_lines.first.update_attributes! hts_code: "1234578906"

      file = subject.run_report importer, tz.parse("2017-05-01 07:00"), tz.parse("2017-05-01 12:30")
      reader = XlsxTestReader.new(file.path).raw_workbook_data
      sheet = reader["Entry ISF Match"]
      expect(sheet.count).to eq 2

      expect(sheet[1]).to eq ["TRANS", "MBOL", "HBOL1", "REF", "BRAND", "PO", "PO", "PART", "PART", "CO", "CO", "1234.56.7890", nil, nil, nil, nil, "", "", "1234.57.8906", "Y", "Y", "Y", "Y", "N", "The ISF line with PO # 'PO' and Part 'PART' did not match to HTS # '1234.56.7890'."]
    end

    it "reports HTS and Country of Origin mismatches in exception notes" do
      isf.security_filing_lines.first.update_attributes! hts_code: "1234578906", country_of_origin_code: "ISF"

      file = subject.run_report importer, tz.parse("2017-05-01 07:00"), tz.parse("2017-05-01 12:30")
      reader = XlsxTestReader.new(file.path).raw_workbook_data
      sheet = reader["Entry ISF Match"]
      expect(sheet.count).to eq 2

      expect(sheet[1]).to eq ["TRANS", "MBOL", "HBOL1", "REF", "BRAND", "PO", "PO", "PART", "PART", "CO", "ISF", "1234.56.7890", nil, nil, nil, nil, "", "", "1234.57.8906", "Y", "Y", "Y", "N", "N", "The ISF line with PO # 'PO' and Part 'PART' did not match to HTS # '1234.56.7890' and did not match to Country 'CO'."]
    end

    it "does not report if hts matches first 6 digits, but doesn't match the rest of the digits" do
      isf.security_filing_lines.first.update_attributes! hts_code: "1234561234"

      file = subject.run_report importer, tz.parse("2017-05-01 07:00"), tz.parse("2017-05-01 12:30")
      reader = XlsxTestReader.new(file.path).raw_workbook_data
      sheet = reader["Entry ISF Match"]
      expect(sheet.count).to eq 1
    end

    it "does not report entries that are not non-Ocean transport modes" do
      entry.update_attributes! transport_mode_code: "40"
      isf.security_filing_lines.first.update_attributes! po_number: "ISF"

      file = subject.run_report importer, tz.parse("2017-05-01 07:00"), tz.parse("2017-05-01 12:30")
      reader = XlsxTestReader.new(file.path).raw_workbook_data
      sheet = reader["Entry ISF Match"]
      expect(sheet.count).to eq 1
    end

    it "does not report entries that are outside the time range" do
      entry.update_attributes! first_entry_sent_date: tz.parse("2017-05-01 12:31")

      file = subject.run_report importer, tz.parse("2017-05-01 07:00"), tz.parse("2017-05-01 12:30")
      reader = XlsxTestReader.new(file.path).raw_workbook_data
      sheet = reader["Entry ISF Match"]
      expect(sheet.count).to eq 1
    end

    it "does not report entries prior to 4/21/2017" do
      entry.update_attributes! first_entry_sent_date: tz.parse("2017-04-20 00:00")

      file = subject.run_report importer, tz.parse("2017-04-01 07:00"), tz.parse("2017-05-01 12:30")
      reader = XlsxTestReader.new(file.path).raw_workbook_data
      sheet = reader["Entry ISF Match"]
      expect(sheet.count).to eq 1
    end

    it "falls back to matching by house bill" do
      isf.update_attributes! master_bill_of_lading: nil, house_bills_of_lading: "HBOL2"

      file = subject.run_report importer, tz.parse("2017-03-01 07:00"), tz.parse("2017-03-01 12:30")
      reader = XlsxTestReader.new(file.path).raw_workbook_data
      sheet = reader["Entry ISF Match"]
      expect(sheet.count).to eq 1
    end

    it "handles matching across multiple tariff lines" do
      # Make the last tariff number match the isf
      line = entry.commercial_invoices.first.commercial_invoice_lines.first
      line.commercial_invoice_tariffs.first.update_attributes! hts_code: "9876543210"
      line.commercial_invoice_tariffs.create! hts_code: "5678901234"
      line.commercial_invoice_tariffs.create! hts_code: "1234567890"

      file = subject.run_report importer, tz.parse("2017-04-01 07:00"), tz.parse("2017-05-01 12:30")
      reader = XlsxTestReader.new(file.path).raw_workbook_data
      sheet = reader["Entry ISF Match"]
      expect(sheet).not_to be_nil
      expect(sheet.count).to eq 1
    end

    it "insures that a special HTS starting with 9903 comes before a special HTS starting with 9902" do
      line = entry.commercial_invoices.first.commercial_invoice_lines.first
      line.commercial_invoice_tariffs.first.update_attributes! hts_code: "9902123456", special_tariff: true
      line.commercial_invoice_tariffs.create! hts_code: "9903123456", special_tariff: true
      line.commercial_invoice_tariffs.create! hts_code: "9876543210"

      file = subject.run_report importer, tz.parse("2017-04-01 07:00"), tz.parse("2017-05-01 12:30")
      reader = XlsxTestReader.new(file.path).raw_workbook_data
      sheet = reader["Entry ISF Match"]
      expect(sheet).not_to be_nil
      expect(sheet.count).to eq 2

      expect(sheet[1][11..17]).to eq ["9876.54.3210", nil, nil, nil, nil, "9903.12.3456", "9902.12.3456"]
      expect(sheet[1].last).to eq "The ISF line with PO # 'PO' and Part 'PART' did not match to HTS #s '9902.12.3456', '9903.12.3456', '9876.54.3210'."
    end

    it "insures that the standard HTS is in the first HTS column" do
      line = entry.commercial_invoices.first.commercial_invoice_lines.first
      line.commercial_invoice_tariffs.first.update_attributes! hts_code: "1111111111", special_tariff: true
      line.commercial_invoice_tariffs.create! hts_code: "5678901234", special_tariff: true
      line.commercial_invoice_tariffs.create! hts_code: "9876543210"

      file = subject.run_report importer, tz.parse("2017-04-01 07:00"), tz.parse("2017-05-01 12:30")
      reader = XlsxTestReader.new(file.path).raw_workbook_data
      sheet = reader["Entry ISF Match"]
      expect(sheet).not_to be_nil
      expect(sheet.count).to eq 2

      expect(sheet[1][11..17]).to eq ["9876.54.3210", nil, nil, nil, nil, "5678.90.1234", "1111.11.1111"]
      expect(sheet[1].last).to eq "The ISF line with PO # 'PO' and Part 'PART' did not match to HTS #s '1111.11.1111', '5678.90.1234', '9876.54.3210'."
    end

    it "reports all unmatched tariffs" do
      # Make sure none of the tariffs match
      line = entry.commercial_invoices.first.commercial_invoice_lines.first
      line.commercial_invoice_tariffs.first.update_attributes! hts_code: "9876543210"
      line.commercial_invoice_tariffs.create! hts_code: "5678901234", special_tariff: true
      line.commercial_invoice_tariffs.create! hts_code: "1111111111", special_tariff: true

      file = subject.run_report importer, tz.parse("2017-04-01 07:00"), tz.parse("2017-05-01 12:30")
      reader = XlsxTestReader.new(file.path).raw_workbook_data
      sheet = reader["Entry ISF Match"]
      expect(sheet).not_to be_nil
      expect(sheet.count).to eq 2

      expect(sheet[1][11..17]).to eq ["9876.54.3210", nil, nil, nil, nil, "5678.90.1234", "1111.11.1111"]
      expect(sheet[1].last).to eq "The ISF line with PO # 'PO' and Part 'PART' did not match to HTS #s '9876.54.3210', '5678.90.1234', '1111.11.1111'."
    end
  end


  describe "run_schedulable" do

    let (:tempfile) {
      t = Tempfile.new ["file", ".txt"]
      Attachment.add_original_filename_method t, "file.txt"
      t
    }

    let! (:ascena) { with_customs_management_id(Factory(:importer), "ASCE")}

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
