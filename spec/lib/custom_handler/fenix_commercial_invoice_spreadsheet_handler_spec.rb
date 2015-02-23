require 'spec_helper'
require "open_chain/custom_handler/fenix_invoice_generator"

describe OpenChain::CustomHandler::FenixCommercialInvoiceSpreadsheetHandler do

  describe 'process' do
    before :each do 
      @cf = double("Custom File")
      @cf.stub(:attached).and_return @cf
      @cf.stub(:path).and_return "path/to/file.xlsx"
      @cf.stub(:attached_file_name).and_return "file.xlsx"

      @user = Factory(:master_user)
      @h = described_class.new @cf
    end

    it "should parse the file" do
      @h.should_receive(:parse).with(@cf.attached.path).and_return []
      @h.process @user

      @user.messages.length.should eq 1
      @user.messages.first.subject.should eq "Fenix Invoice File Processing Completed"
      @user.messages.first.body.should eq "Fenix Invoice File '#{@cf.attached_file_name}' has finished processing."
    end

    it "should put errors into the user messages" do
      @h.should_receive(:parse).with(@cf.attached.path).and_return ["Error1", "Error2"]

      @h.process @user

      @user.messages.length.should eq 1
      @user.messages.first.subject.should eq "Fenix Invoice File Processing Completed With Errors"
      @user.messages.first.body.should eq "Fenix Invoice File '#{@cf.attached_file_name}' has finished processing.\n\nError1\nError2"
    end

    it "should handle uncaught errors" do
      @h.should_receive(:parse).with(@cf.attached.path).and_raise "Error"

      expect {@h.process(@user)}.to raise_error "Error"

      @user.messages.first.subject.should eq "Fenix Invoice File Processing Completed With Errors"
      @user.messages.first.body.should eq "Fenix Invoice File '#{@cf.attached_file_name}' has finished processing.\n\nUnrecoverable errors were encountered while processing this file.  These errors have been forwarded to the IT department and will be resolved."
    end
  end

  describe 'parse' do

    before :each do
      @user = Factory(:master_user)
      @h = described_class.new @cf

      @importer = Factory(:company, importer: true, fenix_customer_number: "CUST1")

      @xl_client = double("XLClient")
      @h.stub(:file_reader).and_return @xl_client
    end

    it "should parse a file using the xlcient" do
      # Using dots in hts numbers here to ensure they're stripped, make sure we
      # also test the alternate date formats here too
      file_contents = [
        ["Column", "Heading"],
        [@importer.fenix_customer_number, "INV1", "2013-10-28", "UIL", "Part1", "CN", "1234.56.7890", "Some Part", "10", "1.25", "PO#", "1", "UNIQUEID"],
        [@importer.fenix_customer_number, "INV1", "2013-10-29", "UPA", "Part2", "HK", "9876543210", "Some Part 2", "20", "1.50", "PO#", "2"],
        [@importer.fenix_customer_number, "INV2", "10/29/2013", "UPA", "Part3", "TW", "1597534682", "Some Part 3", "30", "1.75", "PO #2", "1"],
        [@importer.fenix_customer_number, "INV3", "10/30/13", "UPA", "Part3", "TW", "1597534682", "Some Part 3", "30", "1.75", "PO #2", "1"]
      ]
      @xl_client.should_receive(:all_row_values).and_yield(file_contents[0]).and_yield(file_contents[1]).and_yield(file_contents[2]).and_yield(file_contents[3]).and_yield(file_contents[4])

      OpenChain::CustomHandler::FenixInvoiceGenerator.should_receive(:generate).exactly(3).times

      errors = @h.parse "file.xlsx"
      errors.length.should eq 0

      invoices = CommercialInvoice.where("invoice_number in (?)", ["INV1", "INV2", "INV3"]).order("commercial_invoices.id ASC").all
      invoices.length.should eq 3

      invoice = invoices.first

      invoice.invoice_date.should eq Date.new(2013, 10, 28)
      invoice.country_origin_code.should eq "UIL"
      invoice.currency.should eq 'CAD'

      l = invoice.commercial_invoice_lines.first
      l.part_number.should eq "Part1"
      l.country_origin_code.should eq "CN"
      l.quantity.should eq BigDecimal.new(10)
      l.unit_price.should eq BigDecimal.new("1.25")
      l.po_number.should eq "PO#"
      l.customer_reference.should eq "UNIQUEID"
      t = l.commercial_invoice_tariffs.first
      t.hts_code.should eq "1234567890"
      t.tariff_description.should eq "Some Part"
      t.tariff_provision.should eq "1"

      l = invoice.commercial_invoice_lines.second
      l.part_number.should eq "Part2"
      l.country_origin_code.should eq "HK"
      l.quantity.should eq BigDecimal.new(20)
      l.unit_price.should eq BigDecimal.new("1.50")
      l.customer_reference.should eq ""
      t = l.commercial_invoice_tariffs.first
      t.hts_code.should eq "9876543210"
      t.tariff_description.should eq "Some Part 2"
      t.tariff_provision.should eq "2"

      invoice = invoices.second

      invoice.invoice_date.should eq Date.new(2013, 10, 29)
      invoice.country_origin_code.should eq "UPA"
      invoice.currency.should eq 'CAD'

      l = invoice.commercial_invoice_lines.first
      l.part_number.should eq "Part3"
      l.country_origin_code.should eq "TW"
      l.quantity.should eq BigDecimal.new(30)
      l.unit_price.should eq BigDecimal.new("1.75")
      l.po_number.should eq "PO #2"
      t = l.commercial_invoice_tariffs.first
      t.hts_code.should eq "1597534682"
      t.tariff_description.should eq "Some Part 3"
      t.tariff_provision.should eq "1"

      invoice = invoices[2]
      invoice.invoice_date.should eq Date.new(2013, 10, 30)
    end

    it "should create multiple invoices if blank rows are between each" do
      file_contents = [
        ["Column", "Heading"],
        [@importer.fenix_customer_number, "INV1", "2013-10-28", "UIL", "Part1", "CN", "1234.56.7890", "Some Part", "10", "1.25", "PO#", "1"],
        [],
        ['', '', ' '],
        [@importer.fenix_customer_number, "INV2", "2013-10-29", "UPA", "Part3", "TW", "1597534682", "Some Part 3", "30", "1.75", "PO #2", "1"]
      ]

      @xl_client.should_receive(:all_row_values).and_yield(file_contents[0]).and_yield(file_contents[1]).and_yield(file_contents[2]).and_yield(file_contents[3]).and_yield(file_contents[4])

      OpenChain::CustomHandler::FenixInvoiceGenerator.should_receive(:generate).twice

      errors = @h.parse "file.xlsx"
      errors.length.should eq 0

      invoices = CommercialInvoice.where("invoice_number in (?)", ["INV1", "INV2"]).order("commercial_invoices.id ASC").all
      invoices.length.should eq 2
    end

    it "should error if importer is not found" do
      file_contents = [["Column", "Heading"],["NOIMPORTER", "INV1", "2013-10-28", "UIL", "Part1", "CN", "1234.56.7890", "Some Part", "10", "1.25", "PO#", "1"]]
      @xl_client.should_receive(:all_row_values).and_yield(file_contents[0]).and_yield(file_contents[1])
      OpenChain::CustomHandler::FenixInvoiceGenerator.should_not_receive(:generate)

      errors = @h.parse "file.xlsx"
      errors.length.should eq 1
      errors[0].should include("No Fenix Importer associated with the Tax ID 'NOIMPORTER'.")
    end

    it "should error if importer is blank" do
      @importer = Factory(:company, importer: true, fenix_customer_number: "  ")
      file_contents = [["Column", "Heading"],["  ", "INV1", "2013-10-28", "UIL", "Part1", "CN", "1234.56.7890", "Some Part", "10", "1.25", "PO#", "1"]]
      @xl_client.should_receive(:all_row_values).and_yield(file_contents[0]).and_yield(file_contents[1])
      OpenChain::CustomHandler::FenixInvoiceGenerator.should_not_receive(:generate)

      errors = @h.parse "file.xlsx"
      errors.length.should eq 1
      errors[0].should include("No Fenix Importer associated with the Tax ID '  '.")
    end

    it "should not send invoices if suppressed" do
      file_contents = [["Column", "Heading"],[@importer.fenix_customer_number, "INV1", "2013-10-28", "UIL", "Part1", "CN", "1234.56.7890", "Some Part", "10", "1.25", "PO#", "1"]]
      @xl_client.should_receive(:all_row_values).and_yield(file_contents[0]).and_yield(file_contents[1])
      OpenChain::CustomHandler::FenixInvoiceGenerator.should_not_receive(:generate)

      errors = @h.parse "file.xlsx", true
      errors.length.should eq 0

      CommercialInvoice.where(invoice_number: "INV1").first.should_not be_nil
    end

    it "should update existing invoices" do
      line = Factory(:commercial_invoice_line)
      inv = line.commercial_invoice
      inv.update_attributes importer_id: @importer.id
      id = inv.id

      file_contents = [["Column", "Heading"],[@importer.fenix_customer_number, "#{inv.invoice_number}", "2013-10-28", "UIL", "Part1", "CN", "1234.56.7890", "Some Part", "10", "1.25", "PO#", "1"]]
      @xl_client.should_receive(:all_row_values).and_yield(file_contents[0]).and_yield(file_contents[1])

      errors = @h.parse "file.xlsx", true
      errors.length.should eq 0

      invoice = CommercialInvoice.where(invoice_number: inv.invoice_number).first
      invoice.id.should eq id

      invoice.commercial_invoice_lines.length.should eq 1
    end

    it "should not update existing invoices with a blank invoice number" do
      line = Factory(:commercial_invoice_line)
      inv = line.commercial_invoice
      inv.update_attributes importer_id: @importer.id, invoice_number: ""
      id = inv.id

      file_contents = [["Column", "Heading"],[@importer.fenix_customer_number, "#{inv.invoice_number}", "2013-10-28", "UIL", "Part1", "CN", "1234.56.7890", "Some Part", "10", "1.25", "PO#", "1"]]
      @xl_client.should_receive(:all_row_values).and_yield(file_contents[0]).and_yield(file_contents[1])

      errors = @h.parse "file.xlsx", true
      errors.length.should eq 0

      invoices = CommercialInvoice.where(invoice_number: "").order("commercial_invoices.id ASC").all
      invoices.length.should eq 2

      invoices[0].id.should eq id
      # Check the only other value from the header we set to make sure it matches the new data
      invoices[1].country_origin_code.should eq "UIL"
    end

    it "should properly translate numeric values to text for text model attributes" do
      file_contents = [
        ["Column", "Heading"],
        [@importer.fenix_customer_number, 123.0, "2013-10-28", "UIL", BigDecimal.new("1234.0"), "CN", 12345, "Some Part", "10", "1.25", 1234.1, 1],
      ]
      @xl_client.should_receive(:all_row_values).and_yield(file_contents[0]).and_yield(file_contents[1])
      errors = @h.parse "file.xlsx", true
  
      errors.length.should eq 0

      invoices = CommercialInvoice.where(invoice_number: "123").order("commercial_invoices.id ASC").all
      invoices.length.should eq 1

      inv = invoices.first

      inv.invoice_number.should eq "123"
      l = inv.commercial_invoice_lines.first
      l.part_number.should eq "1234"
      l.po_number.should eq "1234.1"

      t = l.commercial_invoice_tariffs.first
      t.hts_code.should eq "12345"
      t.tariff_provision.should eq "1"

    end
  end

  describe "file_reader" do
    it "uses csvclient for csv files" do
      expect(described_class.new(nil).send(:file_reader, "path/to/file.csv").class).to eq OpenChain::CustomHandler::FenixCommercialInvoiceSpreadsheetHandler::CsvClient
    end

    it "uses csvclient for txt files" do
      expect(described_class.new(nil).send(:file_reader, "path/to/file.txt").class).to eq OpenChain::CustomHandler::FenixCommercialInvoiceSpreadsheetHandler::CsvClient
    end

    it "uses xlclient for xls files" do
      expect(described_class.new(nil).send(:file_reader, "path/to/file.xls").class).to eq OpenChain::XLClient
    end

    it "uses xlclient for xlsx files" do
      expect(described_class.new(nil).send(:file_reader, "path/to/file.xlsx").class).to eq OpenChain::XLClient
    end

    it "raies an error on other file types" do
      expect {described_class.new(nil).send(:file_reader, "path/to/file.blah")}.to raise_error
    end
  end

  describe "CsvClient" do
    before :each do
      @tempfile = Tempfile.new ['temp', '.csv']
      @tempfile.binmode 
      @tempfile << "header1,header2\ndata1,data2"
      @tempfile.flush
      @tempfile.rewind

      @client = described_class.new(nil).send(:file_reader, "path/to/file.csv")
      OpenChain::S3.should_receive(:download_to_tempfile).with('chain-io', "path/to/file.csv").and_yield @tempfile
    end

    after :each do
      @tempfile.close!
    end

    it "yields each row to a block" do
      rows = []
      @client.all_row_values(0) do |row|
        rows << row
      end

      expect(rows).to eq [
        ["header1", "header2"],
        ["data1", "data2"]
      ]
    end

    it "passes back all rows" do
      expect(@client.all_row_values(0)).to eq [
        ["header1", "header2"],
        ["data1", "data2"]
      ]
    end
  end
end