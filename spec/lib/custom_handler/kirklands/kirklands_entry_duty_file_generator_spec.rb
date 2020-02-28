describe OpenChain::CustomHandler::Kirklands::KirklandsEntryDutyFileGenerator do

  let (:user) { Factory(:user) }

  let (:entry) {
    e = Factory(:entry, entry_number: "316000001", entry_filed_date: Date.new(2019, 10, 1), vessel: "Vessel", voyage: "Voyage", export_date: Date.new(2019, 9, 1))
    i = Factory(:commercial_invoice, entry: e)
    line = Factory(:commercial_invoice_line, commercial_invoice: i, part_number: "PART1", po_number: "PO1", quantity: 10, prorated_mpf: 1, hmf: 2, cotton_fee: 3, add_duty_amount: 4, cvd_duty_amount: 5, other_fees: 6)
    tariff = Factory(:commercial_invoice_tariff, commercial_invoice_line: line, hts_code: "1234567890", spi_primary: "SPI", duty_advalorem: 7, duty_specific: 8, duty_other: 9)
    tariff_2 = Factory(:commercial_invoice_tariff, commercial_invoice_line: line, hts_code: "987654321", spi_primary: "SPI2", duty_advalorem: 1, duty_specific: 2, duty_other: 3)
    e
  }

  let (:entry_snapshot) {
    JSON.parse(CoreModule.find_by_object(entry).entity_json(entry))
  }


  describe "extract_entry_data" do

    def expect_tariff_data t, hts_code, duty_amount, duty_code, spi
      expect(t.hts_code).to eq hts_code
      expect(t.duty_amount).to eq duty_amount
      expect(t.duty_code).to eq duty_code
      expect(t.spi).to eq spi
    end

    it "generates xml data structs" do
      data = subject.extract_xml_data entry_snapshot
      expect(data).not_to be_nil

      expect(data.pay_to_id).to eq "28432"
      expect(data.entry_number).to eq "316000001"
      expect(data.entry_filed_date).to eq Date.new(2019, 10, 1)
      expect(data.vessel).to eq "Vessel"
      expect(data.voyage).to eq "Voyage"
      expect(data.export_date).to eq Date.new(2019, 9, 1)

      expect(data.invoice_lines.length).to eq 1

      line = data.invoice_lines.first
      expect(line.po_number).to eq "PO1"
      expect(line.part_number).to eq "PART1"
      expect(line.units).to eq 10

      expect(line.tariff_lines.length).to eq 11

      t = line.tariff_lines[0]
      expect_tariff_data(line.tariff_lines[0], "1234567890", 7, "ALC_AV_DTY", "SPI")
      expect_tariff_data(line.tariff_lines[1], "1234567890", 8, "ALC_SP_DTY", "SPI")
      expect_tariff_data(line.tariff_lines[2], "1234567890", 9, "ALC_OT_DTY", "SPI")
      expect_tariff_data(line.tariff_lines[3], "1234567890", 1, "ALC_MPFUS", "SPI")
      expect_tariff_data(line.tariff_lines[4], "1234567890", 2, "ALC_HMFUS", "SPI")
      expect_tariff_data(line.tariff_lines[5], "1234567890", 9, "ALC_FEE", "SPI")
      expect_tariff_data(line.tariff_lines[6], "1234567890", 4, "ALC_ADUS", "SPI")
      expect_tariff_data(line.tariff_lines[7], "1234567890", 5, "ALC_CVDUS", "SPI")
      expect_tariff_data(line.tariff_lines[8], "987654321", 1, "ALC_AV_DTY", "SPI2")
      expect_tariff_data(line.tariff_lines[9], "987654321", 2, "ALC_SP_DTY", "SPI2")
      expect_tariff_data(line.tariff_lines[10], "987654321", 3, "ALC_OT_DTY", "SPI2")
    end

    it "associates invoice line level taxes with first non-special tariff" do
      entry.commercial_invoices.first.commercial_invoice_lines.first.commercial_invoice_tariffs.first.update! special_tariff: true

      data = subject.extract_xml_data entry_snapshot
      line = data.invoice_lines.first
      expect(line.tariff_lines.length).to eq 11

      expect_tariff_data(line.tariff_lines[0], "1234567890", 7, "ALC_AV_DTY", "SPI")
      expect_tariff_data(line.tariff_lines[1], "1234567890", 8, "ALC_SP_DTY", "SPI")
      expect_tariff_data(line.tariff_lines[2], "1234567890", 9, "ALC_OT_DTY", "SPI")
      expect_tariff_data(line.tariff_lines[3], "987654321", 1, "ALC_AV_DTY", "SPI2")
      expect_tariff_data(line.tariff_lines[4], "987654321", 2, "ALC_SP_DTY", "SPI2")
      expect_tariff_data(line.tariff_lines[5], "987654321", 3, "ALC_OT_DTY", "SPI2")
      expect_tariff_data(line.tariff_lines[6], "987654321", 1, "ALC_MPFUS", "SPI2")
      expect_tariff_data(line.tariff_lines[7], "987654321", 2, "ALC_HMFUS", "SPI2")
      expect_tariff_data(line.tariff_lines[8], "987654321", 9, "ALC_FEE", "SPI2")
      expect_tariff_data(line.tariff_lines[9], "987654321", 4, "ALC_ADUS", "SPI2")
      expect_tariff_data(line.tariff_lines[10], "987654321", 5, "ALC_CVDUS", "SPI2")
    end

    it "skips duty amounts that are 0 or blank" do
      entry.commercial_invoices.first.commercial_invoice_lines.first.update! prorated_mpf: nil, hmf: nil, cotton_fee: 0, add_duty_amount: 0, cvd_duty_amount: 0, other_fees: 0

      data = subject.extract_xml_data entry_snapshot
      line = data.invoice_lines.first
      expect(line.tariff_lines.length).to eq 6

      expect_tariff_data(line.tariff_lines[0], "1234567890", 7, "ALC_AV_DTY", "SPI")
      expect_tariff_data(line.tariff_lines[1], "1234567890", 8, "ALC_SP_DTY", "SPI")
      expect_tariff_data(line.tariff_lines[2], "1234567890", 9, "ALC_OT_DTY", "SPI")
      expect_tariff_data(line.tariff_lines[3], "987654321", 1, "ALC_AV_DTY", "SPI2")
      expect_tariff_data(line.tariff_lines[4], "987654321", 2, "ALC_SP_DTY", "SPI2")
      expect_tariff_data(line.tariff_lines[5], "987654321", 3, "ALC_OT_DTY", "SPI2")
    end

    it "skips tariffs that have no duty" do
      entry.commercial_invoices.first.commercial_invoice_lines.first.update! prorated_mpf: nil, hmf: nil, cotton_fee: 0, add_duty_amount: 0, cvd_duty_amount: 0, other_fees: 0
      entry.commercial_invoices.first.commercial_invoice_lines.first.commercial_invoice_tariffs.second.update! duty_advalorem: 0, duty_specific: nil, duty_other: 0

      data = subject.extract_xml_data entry_snapshot
      line = data.invoice_lines.first
      expect(line.tariff_lines.length).to eq 3

      expect_tariff_data(line.tariff_lines[0], "1234567890", 7, "ALC_AV_DTY", "SPI")
      expect_tariff_data(line.tariff_lines[1], "1234567890", 8, "ALC_SP_DTY", "SPI")
      expect_tariff_data(line.tariff_lines[2], "1234567890", 9, "ALC_OT_DTY", "SPI")
    end

    it "skips lines that have no duty" do
      entry.commercial_invoices.first.commercial_invoice_lines.first.update! prorated_mpf: nil, hmf: nil, cotton_fee: 0, add_duty_amount: 0, cvd_duty_amount: 0, other_fees: 0
      entry.commercial_invoices.first.commercial_invoice_lines.first.commercial_invoice_tariffs.first.update! duty_advalorem: 0, duty_specific: nil, duty_other: 0
      entry.commercial_invoices.first.commercial_invoice_lines.first.commercial_invoice_tariffs.second.update! duty_advalorem: 0, duty_specific: nil, duty_other: 0

      data = subject.extract_xml_data entry_snapshot
      expect(data.invoice_lines.length).to eq 0
    end
  end

  describe "generate_xml" do
    let (:entry_data) {
      d = described_class::KirklandsEntryData.new("PAYTOID", "ENTRYNO", Date.new(2019, 10, 1), "VESSEL", "VOYAGE", Date.new(2019, 9, 1), [])
      tariff_line = described_class::KirklandsTariffData.new("1234567890", BigDecimal("10"), "CODE", "SPI")
      d.invoice_lines << described_class::KirklandsInvoiceLineData.new("PO", "PART", BigDecimal("5"), [tariff_line])


      tariff_line2 = described_class::KirklandsTariffData.new("987654321", BigDecimal("20"), "CODE2", "SPI2")
      d.invoice_lines << described_class::KirklandsInvoiceLineData.new("PO2", "PART2", BigDecimal("50"), [tariff_line2])

      d
    }

    it "generates xml document from entry data structs" do
      now = Time.zone.now
      doc, filename = nil
      Timecop.freeze(now) { doc, filename = subject.generate_xml entry_data }

      expect(filename).to eq "CE_ENTRYNO_#{now.strftime("%Y%m%d%H%M%S%L")}.xml"

      expect(doc.root.name).to eq "CEMessage"

      r = doc.root
      expect(r).to have_xpath_value("TransactionInfo/Created", now.strftime("%Y%m%d"))
      expect(r).to have_xpath_value("TransactionInfo/FileName", "CE_ENTRYNO_#{now.strftime("%Y%m%d%H%M%S%L")}.xml")

      expect(r).to have_xpath_value("count(CEData)", 2)

      expect(r).to have_xpath_value("CEData[OrderNo = 'PO']/CustomEntryNo", "ENTRYNO")
      expect(r).to have_xpath_value("CEData[OrderNo = 'PO']/EntryDate", "10/01/2019")
      expect(r).to have_xpath_value("CEData[OrderNo = 'PO']/PayToId", "PAYTOID")
      expect(r).to have_xpath_value("CEData[OrderNo = 'PO']/Vessel", "VESSEL")
      expect(r).to have_xpath_value("CEData[OrderNo = 'PO']/Voyage", "VOYAGE")
      expect(r).to have_xpath_value("CEData[OrderNo = 'PO']/EstDepartDate", "09/01/2019")
      expect(r).to have_xpath_value("CEData[OrderNo = 'PO']/Item", "PART")
      expect(r).to have_xpath_value("CEData[OrderNo = 'PO']/ClearedQty", "5.0")
      expect(r).to have_xpath_value("CEData[OrderNo = 'PO']/Hts", "1234567890")
      expect(r).to have_xpath_value("CEData[OrderNo = 'PO']/CompId", "CODE")
      expect(r).to have_xpath_value("CEData[OrderNo = 'PO']/Amount", "10.0")
      expect(r).to have_xpath_value("CEData[OrderNo = 'PO']/TariffTreatment", "SPI")

      expect(r).to have_xpath_value("CEData[OrderNo = 'PO2']/CustomEntryNo", "ENTRYNO")
      expect(r).to have_xpath_value("CEData[OrderNo = 'PO2']/EntryDate", "10/01/2019")
      expect(r).to have_xpath_value("CEData[OrderNo = 'PO2']/PayToId", "PAYTOID")
      expect(r).to have_xpath_value("CEData[OrderNo = 'PO2']/Vessel", "VESSEL")
      expect(r).to have_xpath_value("CEData[OrderNo = 'PO2']/Voyage", "VOYAGE")
      expect(r).to have_xpath_value("CEData[OrderNo = 'PO2']/EstDepartDate", "09/01/2019")
      expect(r).to have_xpath_value("CEData[OrderNo = 'PO2']/Item", "PART2")
      expect(r).to have_xpath_value("CEData[OrderNo = 'PO2']/ClearedQty", "50.0")
      expect(r).to have_xpath_value("CEData[OrderNo = 'PO2']/Hts", "987654321")
      expect(r).to have_xpath_value("CEData[OrderNo = 'PO2']/CompId", "CODE2")
      expect(r).to have_xpath_value("CEData[OrderNo = 'PO2']/Amount", "20.0")
      expect(r).to have_xpath_value("CEData[OrderNo = 'PO2']/TariffTreatment", "SPI2")

    end
  end

  describe "generate_and_send" do
    it "extracts data from snapshot, generates xml and ftps it" do
      file_data = nil
      now = Time.zone.now
      expect(subject).to receive(:ftp_sync_file) do |file, sync_record, opts|
        file_data = file.read
        expect(file.original_filename).to eq "CE_316000001_#{now.strftime("%Y%m%d%H%M%S%L")}.xml"
        expect(sync_record.syncable).to eq entry
        expect(opts[:folder]).to eq "to_ecs/kirklands_customs_entry_duty_test"
      end


      Timecop.freeze(now) { subject.generate_and_send entry_snapshot }

      entry.reload
      sr = entry.sync_records.first
      expect(sr.trading_partner).to eq "KIRKLANDS_DUTY"
      expect(sr.sent_at).not_to be_nil
      expect(sr.confirmed_at).not_to be_nil

      doc = REXML::Document.new file_data

      expect(doc.root.name).to eq "CEMessage"
      expect(doc.root).to have_xpath_value("count(CEData)", 11)
    end

    it "ftps file to production location" do
      ms = stub_master_setup
      expect(ms).to receive(:production?).and_return true

      file_data = nil
      now = Time.zone.now
      expect(subject).to receive(:ftp_sync_file) do |file, sync_record, opts|
        expect(opts[:folder]).to eq "to_ecs/kirklands_customs_entry_duty"
      end


      Timecop.freeze(now) { subject.generate_and_send entry_snapshot }
    end

    it "skips files without invoice_lines" do
      fake_data = described_class::KirklandsEntryData.new
      fake_data.invoice_lines = []
      expect(subject).to receive(:extract_xml_data).with(entry_snapshot).and_return fake_data
      expect(subject).not_to receive(:ftp_sync_file)

      subject.generate_and_send entry_snapshot
    end

    it "skips files where entry cannot be found" do
      expect(subject).to receive(:find_entity_object).with(entry_snapshot).and_return nil
      expect(subject).not_to receive(:ftp_sync_file)

      subject.generate_and_send entry_snapshot
    end
  end
end