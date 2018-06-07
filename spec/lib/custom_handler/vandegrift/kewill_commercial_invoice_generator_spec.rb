require 'spec_helper'

describe OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator do

  let(:entry_data) {
    e = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadEntry.new '597549', 'SALOMON', []
    i = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoice.new '15MSA10', Date.new(2015,11,1), []
    i.non_dutiable_amount = BigDecimal("5")
    i.add_to_make_amount = BigDecimal("25")
    e.invoices << i
    l = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new
    l.part_number = "PART"
    l.country_of_origin = "PH"
    l.gross_weight = BigDecimal("78")
    l.pieces = BigDecimal("93")
    l.hts = "4202.92.3031"
    l.foreign_value = BigDecimal("3177.86")
    l.quantity_1 = BigDecimal("93")
    l.quantity_2 = BigDecimal("52")
    l.po_number = "5301195481"
    l.first_sale = BigDecimal("218497.20")
    l.department = 1.0
    l.add_to_make_amount = BigDecimal("15")
    l.non_dutiable_amount = BigDecimal("20")
    l.cotton_fee_flag = ""
    l.mid = "PHMOUINS2106BAT"
    l.cartons = BigDecimal("10")
    l.spi = "JO"
    l.unit_price = BigDecimal("15.50")
    i.invoice_lines << l

    l = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new
    l.part_number = "PART2"
    l.country_of_origin = "PH"
    l.gross_weight = BigDecimal("78")
    l.pieces = BigDecimal("93")
    l.hts = "4202.92.3031"
    l.foreign_value = BigDecimal("3177.86")
    l.quantity_1 = BigDecimal("93")
    l.quantity_2 = BigDecimal("52")
    l.po_number = "5301195481"
    l.first_sale = BigDecimal("218497.20")
    l.department = 1.0
    l.add_to_make_amount = BigDecimal("15")
    l.non_dutiable_amount = BigDecimal("20")
    l.cotton_fee_flag = ""
    l.mid = "PHMOUINS2106BAT"
    l.cartons = BigDecimal("20")
    l.spi = "JO"
    l.unit_price = BigDecimal("15.50")
    i.invoice_lines << l

    e
  }

  describe "generate_and_send" do
    it "generates data to a tempfile and ftps it" do
      filename = nil
      data = nil
      expect(subject).to receive(:ftp_file) do |temp|
        data = temp.read
        filename = File.basename(temp.path)
      end
      subject.generate_and_send [entry_data]

      doc = REXML::Document.new data
      expect(REXML::XPath.first doc, "/requests/request/kcData/ediShipments/ediShipment").not_to be_nil
      expect(filename).to start_with "CI_Load_597549_"
      expect(filename).to end_with ".xml"
    end

    it "catches data overflow errors and re-raises them as MissingCiLoadDataError" do
      # File number overflows at 15 chars
      entry_data.file_number = "1234567890123456"

      ex = nil
      begin
        subject.generate_and_send [entry_data]
        fail("Should have raised an error.")
      rescue OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::MissingCiLoadDataError => e
        ex = e
      end

      expect(ex.message).to eq "String '#{entry_data.file_number}' is longer than 15 characters"
      expect(ex.backtrace).not_to be_blank
    end
  end

  describe "ftp_credentials" do
    it "uses credentials for connect.vfitrack.net" do
      expect(subject.ftp_credentials).to eq(
        {server: 'connect.vfitrack.net', username: 'ecs', password: 'wzuomlo', folder: "kewill_edi/to_kewill", protocol: 'sftp', port: 2222}
      )
    end
  end

  describe "generate_and_send_invoices" do
    let (:importer) {
      Company.new importer: true, alliance_customer_number: "IMP"
    }
    let (:invoice) {
      i = CommercialInvoice.new
      i.invoice_number = "INV#"
      i.invoice_date = Date.new(2016, 5, 9)
      i.importer = importer

      l = i.commercial_invoice_lines.build
      l.po_number = "PO"
      l.part_number = "PART"
      l.quantity = BigDecimal("10")
      l.unit_price = BigDecimal("1.50")
      l.country_origin_code = "CN"
      l.value = BigDecimal("2.50")
      l.contract_amount = BigDecimal("2.00")
      l.department = "DEPT"
      l.mid = "MID"

      t = l.commercial_invoice_tariffs.build
      t.hts_code = "1234567890"
      t.classification_qty_1 = BigDecimal("10")
      t.classification_qty_2 = BigDecimal("5")
      t.gross_weight = BigDecimal("100")
      t.spi_primary = "AU"

      i
    }

    it "receives commercial invoices, translates them to internal file objects and sends them" do
      entry = nil
      expect(subject).to receive(:generate_and_send) do |entries|
        expect(entries.length).to eq 1
        entry = entries.first
      end

      subject.generate_and_send_invoices("12345", invoice)

      expect(entry.file_number).to eq "12345"
      expect(entry.customer).to eq "IMP"
      expect(entry.invoices.length).to eq 1

      i = entry.invoices.first
      expect(i.invoice_number).to eq "INV#"
      expect(i.invoice_date).to eq Date.new(2016, 5, 9)
      expect(i.invoice_lines.length).to eq 1

      i = i.invoice_lines.first
      expect(i.po_number).to eq "PO"
      expect(i.part_number).to eq "PART"
      expect(i.pieces).to eq 10
      expect(i.unit_price).to eq 1.50
      expect(i.country_of_origin).to eq "CN"
      expect(i.foreign_value).to eq 2.50
      expect(i.first_sale).to eq 2
      expect(i.department).to eq "DEPT"
      expect(i.mid).to eq "MID"

      expect(i.hts).to eq "1234567890"
      expect(i.quantity_1).to eq 10
      expect(i.quantity_2).to eq 5
      expect(i.gross_weight).to eq 100
      expect(i.spi).to eq "AU"

    end

    it "converts gross weight from grams to KG if instructed" do
      invoice.commercial_invoice_lines.first.commercial_invoice_tariffs.first.gross_weight = 1000
      entry = nil
      expect(subject).to receive(:generate_and_send) do |entries|
        expect(entries.length).to eq 1
        entry = entries.first
      end

      subject.generate_and_send_invoices("12345", invoice, gross_weight_uom: "G")

      expect(entry.invoices.first.invoice_lines.first.gross_weight).to eq 1
    end

    it "converts gross weight from grams to KG, sending 1 KG if converted weight is less than 1 KG" do
      invoice.commercial_invoice_lines.first.commercial_invoice_tariffs.first.gross_weight = 10
      entry = nil
      expect(subject).to receive(:generate_and_send) do |entries|
        expect(entries.length).to eq 1
        entry = entries.first
      end

      subject.generate_and_send_invoices("12345", invoice, gross_weight_uom: "G")

      expect(entry.invoices.first.invoice_lines.first.gross_weight).to eq 1
    end

    it "does not send 1 KG if weight is not converted" do
      invoice.commercial_invoice_lines.first.commercial_invoice_tariffs.first.gross_weight = BigDecimal("0.50")

      entry = nil
      expect(subject).to receive(:generate_and_send) do |entries|
        expect(entries.length).to eq 1
        entry = entries.first
      end

      subject.generate_and_send_invoices("12345", invoice)
      expect(entry.invoices.first.invoice_lines.first.gross_weight).to eq 0
    end
  end

  describe "generate_xls" do
    it "generates an excel workbook" do
      l = entry_data.invoices.first.invoice_lines.first
      l.seller_mid = "SELLER"
      l.buyer_customer_number = "BUYER"

      wb = subject.generate_xls [entry_data]
      expect(wb).not_to be_nil

      sheet = wb.worksheet("CI Load")
      expect(sheet).not_to be_nil

      expect(sheet.row(0)).to eq ["File #", "Customer", "Invoice #", "Invoice Date", "Country of Origin", "Part # / Style", "Pieces", "MID", "Tariff #", "Cotton Fee (Y/N)", "Invoice Foreign Value", "Quantity 1", "Quantity 2", "Gross Weight", "PO #", "Cartons", "First Sale Amount", "NDC / MMV", "Department", "SPI", "Buyer Cust No", "Seller MID"]
      expect(sheet.row(1)).to eq ['597549', 'SALOMON', '15MSA10', '2015-11-01', "PH", "PART", 93.0, "PHMOUINS2106BAT", "4202.92.3031", "N", 3177.86, 93.0, 52.0, 78.0, "5301195481", 10, 218497.20, 20.0, 1.0, "JO", "BUYER", "SELLER"]
      # just make sure the second line has the second part and retains the entry/invoice info
      expect(sheet.row(2)[0..5]).to eq ['597549', 'SALOMON', '15MSA10', '2015-11-01', "PH", "PART2"]
      expect(sheet.row(3)).to eq []
    end
  end

  describe "generate_xls_to_google_drive" do
    let (:workbook) {
      wb = instance_double(Spreadsheet::Workbook)
      allow(wb).to receive(:write) do |t|
        t << "Test"
      end
      wb
    }

    it "generates an excel workbook and loads it to drive" do
      tf = nil
      expect(OpenChain::GoogleDrive).to receive(:upload_file) do |path, file|
        expect(path).to eq "path/to/file.xls"
        expect(file).to be_a Tempfile
        expect(file.read).to eq "Test"
        tf = file
        nil
      end

      expect(subject).to receive(:generate_xls).with([]).and_return workbook

      subject.generate_xls_to_google_drive("path/to/file.xls", [])
      expect(tf.closed?).to eq true
    end
  end
end