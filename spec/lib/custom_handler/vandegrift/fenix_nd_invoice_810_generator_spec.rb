describe OpenChain::CustomHandler::Vandegrift::FenixNdInvoice810Generator do

  let (:us) { FactoryBot(:country, iso_code: "US") }
  let (:cn) { FactoryBot(:country, iso_code: "CN") }

  let (:importer) {
    Company.new name: "Importer", addresses: [Address.new(line_1: "123 Importer St.", line_2: "Suite 123", city: "Fakesville", state: "PA", postal_code: "12345", country: us)]
  }

  let (:vendor) {
   Company.new name: "Vendor", name_2: "V2", addresses: [Address.new(line_1: "123 Vendor St.", line_2: "Suite 123", city: "Fakesville", state: "PA", postal_code: "12345", country: us)]
  }

  let (:consignee) {
   Company.new name: "Consignee", name_2: "C2", addresses: [Address.new(line_1: "123 Consignee St.", line_2: "Suite 123", city: "Fakesville", state: "PA", postal_code: "12345", country: us)]
  }

  let (:invoice) {
    i = Invoice.new
    i.invoice_number = "INVOICE"
    i.invoice_date = Date.new(2018, 9, 4)
    i.country_origin = cn
    i.currency = "USD"
    i.gross_weight = BigDecimal("100")
    i.invoice_total_foreign = BigDecimal("1000")
    i.vendor = vendor
    i.consignee = consignee
    i.importer = importer
    i.customer_reference_number = "REF"

    i
  }

  let (:invoice_lines) {
    l = invoice.invoice_lines.build
    l.po_number = "PO"
    l.part_number = "PART"
    l.cartons = 1
    l.carrier_code = "CARR"
    l.master_bill_of_lading = "MBOL"
    l.country_origin = cn
    l.hts_number = "1234567890"
    l.part_description = "DESCRIPTION"
    l.quantity = 10
    l.unit_price = BigDecimal("1.23")
    l.spi = "1"

    l2 = invoice.invoice_lines.build
    l2.po_number = "PO2"
    l2.part_number = "PART2"
    l2.cartons = 2
    l2.carrier_code = "CAR2"
    l2.master_bill_of_lading = "MBOL2"
    l2.country_origin = cn
    l2.hts_number = "1234567892"
    l2.part_description = "DESCRIPTION2"
    l2.quantity = 20
    l2.unit_price = BigDecimal("2.23")
    l2.spi = "2"

    [l, l2]
  }

  describe "write_invoice_810" do
    before :each do
      invoice_lines
    end

    let (:io) { StringIO.new }

    it "writes invoice data to an output" do
      subject.write_invoice_810 io, invoice
      lines = io.read.split("\r\n")
      expect(lines.length).to eq 3

      h = lines[0]
      expect(h[0]).to eq "H"
      expect(h[1, 25]).to eq "INVOICE".ljust(25)
      expect(h[26, 10]).to eq "20180904".ljust(10)
      expect(h[36, 10]).to eq "CN".ljust(10)
      expect(h[46, 10]).to eq "CA".ljust(10)
      expect(h[56, 4]).to eq "USD".ljust(4)
      expect(h[60, 15]).to eq "3".ljust(15)
      expect(h[75, 15]).to eq "100.00".ljust(15)
      expect(h[90, 15]).to eq "30.00".ljust(15)
      expect(h[105, 15]).to eq "1000.00".ljust(15)

      expect(h[120, 50]).to eq "Vendor".ljust(50)
      expect(h[170, 50]).to eq "V2".ljust(50)
      expect(h[220, 50]).to eq "123 Vendor St.".ljust(50)
      expect(h[270, 50]).to eq "Suite 123".ljust(50)
      expect(h[320, 50]).to eq "Fakesville".ljust(50)
      expect(h[370, 50]).to eq "PA".ljust(50)
      expect(h[420, 50]).to eq "12345".ljust(50)

      expect(h[470, 50]).to eq "Consignee".ljust(50)
      expect(h[520, 50]).to eq "C2".ljust(50)
      expect(h[570, 50]).to eq "123 Consignee St.".ljust(50)
      expect(h[620, 50]).to eq "Suite 123".ljust(50)
      expect(h[670, 50]).to eq "Fakesville".ljust(50)
      expect(h[720, 50]).to eq "PA".ljust(50)
      expect(h[770, 50]).to eq "12345".ljust(50)

      expect(h[820, 350]).to eq "GENERIC".ljust(350)
      expect(h[1170, 50]).to eq "PO".ljust(50)
      expect(h[1220]).to eq "2"
      expect(h[1221, 50]).to eq "REF".ljust(50)
      expect(h[1271, 50]). to eq "Importer".ljust(50)
      expect(h[1321, 4]).to eq "CARR"
      expect(h[1325, 30]).to eq "MBOL".ljust(30)

      l = lines[1]

      expect(l[0]).to eq "D"
      expect(l[1, 50]).to eq "PART".ljust(50)
      expect(l[51, 10]).to eq "CN".ljust(10)
      expect(l[61, 12]).to eq "1234567890".ljust(12)
      expect(l[73, 50]).to eq "DESCRIPTION".ljust(50)
      expect(l[123, 15]).to eq "10.00".ljust(15)
      expect(l[138, 15]).to eq "1.23".ljust(15)
      expect(l[153, 50]).to eq "PO".ljust(50)
      expect(l[203, 10]).to eq "1".ljust(10)

      l = lines[2]

      expect(l[0]).to eq "D"
      expect(l[1, 50]).to eq "PART2".ljust(50)
      expect(l[51, 10]).to eq "CN".ljust(10)
      expect(l[61, 12]).to eq "1234567892".ljust(12)
      expect(l[73, 50]).to eq "DESCRIPTION2".ljust(50)
      expect(l[123, 15]).to eq "20.00".ljust(15)
      expect(l[138, 15]).to eq "2.23".ljust(15)
      expect(l[153, 50]).to eq "PO2".ljust(50)
      expect(l[203, 10]).to eq "2".ljust(10)

    end

    it "defaults certain fields" do
      # Unset some values to make sure the mapping outputs defaults
      i = invoice
      i.id = 123
      i.vendor = nil
      i.consignee = nil
      i.importer = nil
      i.invoice_number = nil
      i.invoice_total_foreign = nil
      i.gross_weight = nil
      i.country_origin = nil

      i.invoice_lines.each do |l|
        l.cartons = nil
        l.quantity = nil
        l.po_number = nil
        l.carrier_code = nil
        l.master_bill_of_lading = nil
        l.hts_number = nil
        l.spi = nil
        l.unit_price = nil
      end

      subject.write_invoice_810 io, invoice
      lines = io.read.split("\r\n")
      expect(lines.length).to eq 3

      h = lines[0]
      expect(h[0]).to eq "H"
      expect(h[1, 25]).to eq "VFI-123".ljust(25)
      expect(h[26, 10]).to eq "20180904".ljust(10)
      expect(h[36, 10]).to eq "".ljust(10)
      expect(h[46, 10]).to eq "CA".ljust(10)
      expect(h[56, 4]).to eq "USD".ljust(4)
      expect(h[60, 15]).to eq "0".ljust(15)
      expect(h[75, 15]).to eq "0.00".ljust(15)
      expect(h[90, 15]).to eq "0".ljust(15)
      expect(h[105, 15]).to eq "0.00".ljust(15)
      expect(h[120, 350]).to eq("GENERIC".ljust(350))
      expect(h[470, 350]).to eq("GENERIC".ljust(350))
      expect(h[820, 350]).to eq "GENERIC".ljust(350)
      expect(h[1170, 50]).to eq "".ljust(50)
      expect(h[1220]).to eq "2"
      expect(h[1221, 50]).to eq "REF".ljust(50)
      expect(h[1271, 50]). to eq "".ljust(50)
      expect(h[1321, 4]).to eq "".ljust(4)
      expect(h[1325, 30]).to eq "Not Available".ljust(30)

      l = lines[1]

      expect(l[0]).to eq "D"
      expect(l[1, 50]).to eq "PART".ljust(50)
      expect(l[51, 10]).to eq "CN".ljust(10)
      expect(l[61, 12]).to eq "0".ljust(12)
      expect(l[73, 50]).to eq "DESCRIPTION".ljust(50)
      expect(l[123, 15]).to eq "0.00".ljust(15)
      expect(l[138, 15]).to eq "0.00".ljust(15)
      expect(l[153, 50]).to eq "".ljust(50)
      expect(l[203, 10]).to eq "2".ljust(10)
    end

    it "raises an error if more than max lines are used" do
      expect(subject).to receive(:max_line_count).at_least(1).times.and_return 1

      expect { subject.write_invoice_810 io, invoice }.to raise_error "Invoice # INVOICE generated a Fenix invoice file containing 2 lines. Invoices over 1 lines are not supported and must have detail lines consolidated or the invoice must be split into multiple pieces."
    end
  end

  describe "generate_and_send_810" do
    let (:sync_record) { SyncRecord.new }

    it "generates and sends an 810 file" do
      expect(subject).to receive(:write_invoice_810) do |tempfile, inv|
        expect(tempfile).to be_a(Tempfile)
        expect(inv).to eq invoice
        tempfile << "TEST"
        tempfile.flush

        nil
      end

      expect(subject).to receive(:ftp_sync_file).with(instance_of(Tempfile), sync_record, subject.ftp_connection_info)

      subject.generate_and_send_810 invoice, sync_record
    end

    it "escapes bad chars in invoice name for filename" do
      invoice.invoice_number = "test/testing"

      expect(subject).to receive(:write_invoice_810) do |tempfile, inv|
        expect(File.basename(tempfile)).to start_with("fenix_invoice_test_testing_")

        nil
      end
      expect(subject).to receive(:ftp_sync_file)

      subject.generate_and_send_810 invoice, sync_record
    end

    it "handles errors" do
      e = StandardError.new "Testing"

      expect(subject).to receive(:write_invoice_810).and_raise e
      expect(e).to receive(:log_me)

      subject.generate_and_send_810 invoice, sync_record

      expect(ActionMailer::Base.deliveries.length).to eq 1
      m = ActionMailer::Base.deliveries.first

      expect(m.to).to eq ["edisupport@vandegriftinc.com"]
      expect(m.subject).to eq "Invalid Fenix 810 Invoice for Importer"
      expect(m.body).to include "Testing"
    end
  end
end