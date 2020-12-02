describe OpenChain::CustomHandler::FenixCommercialInvoiceSpreadsheetHandler do

  let (:custom_file) {
    cf = double("Custom File")
    allow(cf).to receive(:attached).and_return cf
    allow(cf).to receive(:path).and_return "path/to/file.xlsx"
    allow(cf).to receive(:attached_file_name).and_return "file.xlsx"

    cf
  }
  let(:user) { create(:master_user) }
  subject { described_class.new custom_file }

  describe 'process' do

    it "should parse the file" do
      expect(subject).to receive(:parse).with(custom_file).and_return []
      subject.process user

      expect(user.messages.length).to eq 1
      expect(user.messages.first.subject).to eq "Fenix Invoice File Processing Completed"
      expect(user.messages.first.body).to eq "Fenix Invoice File '#{custom_file.attached_file_name}' has finished processing."
    end

    it "should put errors into the user messages" do
      expect(subject).to receive(:parse).with(custom_file).and_return ["Error1", "Error2"]

      subject.process user

      expect(user.messages.length).to eq 1
      expect(user.messages.first.subject).to eq "Fenix Invoice File Processing Completed With Errors"
      expect(user.messages.first.body).to eq "Fenix Invoice File '#{custom_file.attached_file_name}' has finished processing.\n\nError1\nError2"
    end

    it "should handle uncaught errors" do
      expect(subject).to receive(:parse).with(custom_file).and_raise "Error"

      expect {subject.process(user)}.to raise_error "Error"

      expect(user.messages.first.subject).to eq "Fenix Invoice File Processing Completed With Errors"
      expect(user.messages.first.body).to eq "Fenix Invoice File '#{custom_file.attached_file_name}' has finished processing.\n\nUnrecoverable errors were encountered while processing this file.  These errors have been forwarded to the IT department and will be resolved."
    end
  end

  describe 'parse' do
    let(:importer) { with_fenix_id(create(:importer), "CUST1") }


    it "should parse a file" do
      date = Time.zone.now.to_date

      file_contents = [
        ["Column", "Heading"],
        [importer.fenix_customer_identifier, "INV1", date.strftime("%Y-%m-%d"), "UIL", "Part1", "CN", "1234.56.7890", "Some Part", "10", "1.25", "PO#", "1", "UNIQUEID"],
        [importer.fenix_customer_identifier, "INV1", date.strftime("%Y-%m-%d"), "UPA", "Part2", "HK", "9876543210", "Some Part 2", "20", "1.50", "PO#", "2"],
        [importer.fenix_customer_identifier, "INV2", date.strftime("%Y-%m-%d"), "UPA", "Part3", "TW", "1597534682", "Some Part 3", "30", "1.75", "PO #2", "1"],
        [importer.fenix_customer_identifier, "INV3", date.strftime("%Y-%m-%d"), "UPA", "Part3", "TW", "1597534682", "Some Part 3", "30", "1.75", "PO #2", "1"]
      ]

      expect(subject).to receive(:foreach).and_yield(file_contents[0]).and_yield(file_contents[1]).and_yield(file_contents[2]).and_yield(file_contents[3]).and_yield(file_contents[4])

      expect(OpenChain::CustomHandler::FenixNdInvoiceGenerator).to receive(:generate).exactly(3).times

      errors = subject.parse custom_file
      expect(errors.length).to eq 0

      invoices = CommercialInvoice.where("invoice_number in (?)", ["INV1", "INV2", "INV3"]).order("commercial_invoices.id ASC").all
      expect(invoices.length).to eq 3

      invoice = invoices.first

      expect(invoice.invoice_date).to eq date
      expect(invoice.country_origin_code).to eq "UIL"
      expect(invoice.currency).to eq 'CAD'

      l = invoice.commercial_invoice_lines.first
      expect(l.part_number).to eq "Part1"
      expect(l.country_origin_code).to eq "CN"
      expect(l.quantity).to eq BigDecimal.new(10)
      expect(l.unit_price).to eq BigDecimal.new("1.25")
      expect(l.po_number).to eq "PO#"
      expect(l.customer_reference).to eq "UNIQUEID"
      t = l.commercial_invoice_tariffs.first
      expect(t.hts_code).to eq "1234567890"
      expect(t.tariff_description).to eq "Some Part"
      expect(t.tariff_provision).to eq "1"

      l = invoice.commercial_invoice_lines.second
      expect(l.part_number).to eq "Part2"
      expect(l.country_origin_code).to eq "HK"
      expect(l.quantity).to eq BigDecimal.new(20)
      expect(l.unit_price).to eq BigDecimal.new("1.50")
      expect(l.customer_reference).to eq ""
      t = l.commercial_invoice_tariffs.first
      expect(t.hts_code).to eq "9876543210"
      expect(t.tariff_description).to eq "Some Part 2"
      expect(t.tariff_provision).to eq "2"

      invoice = invoices.second

      expect(invoice.invoice_date).to eq date
      expect(invoice.country_origin_code).to eq "UPA"
      expect(invoice.currency).to eq 'CAD'

      l = invoice.commercial_invoice_lines.first
      expect(l.part_number).to eq "Part3"
      expect(l.country_origin_code).to eq "TW"
      expect(l.quantity).to eq BigDecimal.new(30)
      expect(l.unit_price).to eq BigDecimal.new("1.75")
      expect(l.po_number).to eq "PO #2"
      t = l.commercial_invoice_tariffs.first
      expect(t.hts_code).to eq "1597534682"
      expect(t.tariff_description).to eq "Some Part 3"
      expect(t.tariff_provision).to eq "1"

      invoice = invoices[2]
      expect(invoice.invoice_date).to eq date
    end

    it "should create multiple invoices if blank rows are between each" do
      file_contents = [
        ["Column", "Heading"],
        [importer.fenix_customer_identifier, "INV1", "2013-10-28", "UIL", "Part1", "CN", "1234.56.7890", "Some Part", "10", "1.25", "PO#", "1"],
        [],
        ['', '', ' '],
        [importer.fenix_customer_identifier, "INV2", "2013-10-29", "UPA", "Part3", "TW", "1597534682", "Some Part 3", "30", "1.75", "PO #2", "1"]
      ]

      expect(subject).to receive(:foreach).and_yield(file_contents[0]).and_yield(file_contents[1]).and_yield(file_contents[2]).and_yield(file_contents[3]).and_yield(file_contents[4])

      expect(OpenChain::CustomHandler::FenixNdInvoiceGenerator).to receive(:generate).twice

      errors = subject.parse "file.xlsx"
      expect(errors.length).to eq 0

      invoices = CommercialInvoice.where("invoice_number in (?)", ["INV1", "INV2"]).order("commercial_invoices.id ASC").all
      expect(invoices.length).to eq 2
    end

    it "should error if importer is not found" do
      file_contents = [["Column", "Heading"], ["NOIMPORTER", "INV1", "2013-10-28", "UIL", "Part1", "CN", "1234.56.7890", "Some Part", "10", "1.25", "PO#", "1"]]
      expect(subject).to receive(:foreach).and_yield(file_contents[0]).and_yield(file_contents[1])
      expect(OpenChain::CustomHandler::FenixNdInvoiceGenerator).not_to receive(:generate)

      errors = subject.parse "file.xlsx"
      expect(errors.length).to eq 1
      expect(errors[0]).to include("No Fenix Importer associated with the Tax ID 'NOIMPORTER'.")
    end

    it "should error if importer is blank" do
      importer = create(:importer)
      file_contents = [["Column", "Heading"], ["  ", "INV1", "2013-10-28", "UIL", "Part1", "CN", "1234.56.7890", "Some Part", "10", "1.25", "PO#", "1"]]
      expect(subject).to receive(:foreach).and_yield(file_contents[0]).and_yield(file_contents[1])
      expect(OpenChain::CustomHandler::FenixNdInvoiceGenerator).not_to receive(:generate)

      errors = subject.parse "file.xlsx"
      expect(errors.length).to eq 1
      expect(errors[0]).to include("No Fenix Importer associated with the Tax ID ''.")
    end

    it "should not send invoices if suppressed" do
      file_contents = [["Column", "Heading"], [importer.fenix_customer_identifier, "INV1", "2013-10-28", "UIL", "Part1", "CN", "1234.56.7890", "Some Part", "10", "1.25", "PO#", "1"]]
      expect(subject).to receive(:foreach).and_yield(file_contents[0]).and_yield(file_contents[1])
      expect(OpenChain::CustomHandler::FenixNdInvoiceGenerator).not_to receive(:generate)

      errors = subject.parse "file.xlsx", true
      expect(errors.length).to eq 0

      expect(CommercialInvoice.where(invoice_number: "INV1").first).not_to be_nil
    end

    it "should update existing invoices" do
      line = create(:commercial_invoice_line)
      inv = line.commercial_invoice
      inv.update_attributes importer_id: importer.id
      id = inv.id

      file_contents = [["Column", "Heading"], [importer.fenix_customer_identifier, "#{inv.invoice_number}", "2013-10-28", "UIL", "Part1", "CN", "1234.56.7890", "Some Part", "10", "1.25", "PO#", "1"]]
      expect(subject).to receive(:foreach).and_yield(file_contents[0]).and_yield(file_contents[1])

      errors = subject.parse "file.xlsx", true
      expect(errors.length).to eq 0

      invoice = CommercialInvoice.where(invoice_number: inv.invoice_number).first
      expect(invoice.id).to eq id

      expect(invoice.commercial_invoice_lines.length).to eq 1
    end

    it "should not update existing invoices with a blank invoice number" do
      line = create(:commercial_invoice_line)
      inv = line.commercial_invoice
      inv.update_attributes importer_id: importer.id, invoice_number: ""
      id = inv.id

      file_contents = [["Column", "Heading"], [importer.fenix_customer_identifier, "#{inv.invoice_number}", "2013-10-28", "UIL", "Part1", "CN", "1234.56.7890", "Some Part", "10", "1.25", "PO#", "1"]]
      expect(subject).to receive(:foreach).and_yield(file_contents[0]).and_yield(file_contents[1])

      errors = subject.parse "file.xlsx", true
      expect(errors.length).to eq 0

      invoices = CommercialInvoice.where(invoice_number: "").order("commercial_invoices.id ASC").all
      expect(invoices.length).to eq 2

      expect(invoices[0].id).to eq id
      # Check the only other value from the header we set to make sure it matches the new data
      expect(invoices[1].country_origin_code).to eq "UIL"
    end

    it "should properly translate numeric values to text for text model attributes" do
      file_contents = [
        ["Column", "Heading"],
        [importer.fenix_customer_identifier, 123.0, "2013-10-28", "UIL", BigDecimal.new("1234.0"), "CN", 12345, "Some Part", "10", "1.25", 1234.1, 1],
      ]
      expect(subject).to receive(:foreach).and_yield(file_contents[0]).and_yield(file_contents[1])
      errors = subject.parse "file.xlsx", true

      expect(errors.length).to eq 0

      invoices = CommercialInvoice.where(invoice_number: "123").order("commercial_invoices.id ASC").all
      expect(invoices.length).to eq 1

      inv = invoices.first

      expect(inv.invoice_number).to eq "123"
      l = inv.commercial_invoice_lines.first
      expect(l.part_number).to eq "1234"
      expect(l.po_number).to eq "1234.1"

      t = l.commercial_invoice_tariffs.first
      expect(t.hts_code).to eq "12345"
      expect(t.tariff_provision).to eq "1"

    end

    it "sends files to Fenix ND generator if master setup says to" do
      ms = double("MasterSetup")
      allow(ms).to receive(:custom_feature?).with("Fenix ND Invoices").and_return true
      allow(MasterSetup).to receive(:get).and_return ms

      # Using dots in hts numbers here to ensure they're stripped, make sure we
      # also test the alternate date formats here too
      file_contents = [
        ["Column", "Heading"],
        [importer.fenix_customer_identifier, "INV1", "2013-10-28", "UIL", "Part1", "CN", "1234.56.7890", "Some Part", "10", "1.25", "PO#", "1", "UNIQUEID"]
      ]
      expect(subject).to receive(:foreach).and_yield(file_contents[0]).and_yield(file_contents[1])

      expect(OpenChain::CustomHandler::FenixNdInvoiceGenerator).to receive(:generate).exactly(1).times

      subject.parse "file.xlsx"
    end
  end

end