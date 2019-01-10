require 'spec_helper'

describe OpenChain::CustomHandler::CiLoadHandler do

  let (:row_data) {
    [
      ["12345", "CUST", "INV-123", "2015-01-01", "US", "PART-1", 12.0, "MID12345", "1234.56.7890", "N", 22.50, 10, 35, 50.5, "Purchase Order", 12, "21.50", "123.45", "19", "A+", "BuyerCustNo", "SellerMID", "X"]
    ]
  }

  describe "parse" do

    let (:file) {
      CustomFile.new attached_file_name: "testing.csv"
    }

    let (:file_parser) {
      d = double("file_parser")
      allow(d).to receive(:file_number_invoice_number_columns).and_return file_number: 0, invoice_number: 2
      allow(d).to receive(:invalid_row?).and_return false

      d
    }

    subject {
      described_class.new file
    }

    it "parses a file into kewill invoice generator objects" do
      expect(subject).to receive(:foreach).with(file, skip_headers: true, skip_blank_lines: true).and_return row_data
      expect(subject).to receive(:file_parser).with(file).and_return file_parser
      # The only data in the entry/invoice that matters is the file # and invoice number
      entry = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadEntry.new "12345", nil, []
      invoice = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoice.new "INV-123", nil, []

      expect(file_parser).to receive(:parse_entry_header).with(row_data[0]).and_return entry
      expect(file_parser).to receive(:parse_invoice_header).with(entry, row_data[0]).and_return invoice
      expect(file_parser).to receive(:parse_invoice_line).with(entry, invoice, row_data[0]).and_return OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new

      results = subject.parse file
      expect(results[:entries].size).to eq 1
      expect(results[:bad_row_count]).to eq 0
      expect(results[:generated_file_numbers]).to eq ["12345"]

      expect(results[:entries].first).to eq entry
      expect(results[:entries].first.invoices).to eq [invoice]
      expect(results[:entries].first.invoices.first.invoice_lines.length).to eq 1
    end

    it "parses multiple files and invoices" do
      data = row_data
      data << ["12345", "CUST", "INV-123", "", "", "PART-2"]
      data << ["54321", "CUST", "INV-321", "", "", "PART-1"]

      expect(subject).to receive(:foreach).and_return row_data
      expect(subject).to receive(:file_parser).with(file).and_return file_parser
      # The only data in the entry/invoice that matters is the file # and invoice number
      entry = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadEntry.new "12345", nil, []
      invoice = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoice.new "INV-123", nil, []
      # The only data in the entry/invoice that matters is the file # and invoice number
      entry2 = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadEntry.new "54321", nil, []
      invoice2 = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoice.new "INV-321", nil, []

      expect(file_parser).to receive(:parse_entry_header).with(row_data[0]).and_return entry
      expect(file_parser).to receive(:parse_invoice_header).with(entry, row_data[0]).and_return invoice
      expect(file_parser).to receive(:parse_invoice_line).with(entry, invoice, row_data[0]).and_return OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new
      expect(file_parser).to receive(:parse_invoice_line).with(entry, invoice, row_data[1]).and_return OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new

      expect(file_parser).to receive(:parse_entry_header).with(row_data[2]).and_return entry2
      expect(file_parser).to receive(:parse_invoice_header).with(entry2, row_data[2]).and_return invoice2
      expect(file_parser).to receive(:parse_invoice_line).with(entry2, invoice2, row_data[2]).and_return OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new

      results = subject.parse file

      expect(results[:entries].size).to eq 2
      expect(results[:bad_row_count]).to eq 0
      expect(results[:generated_file_numbers]).to eq ["12345", "54321"]

      expect(results[:entries].first).to eq entry
      expect(results[:entries].first.invoices).to eq [invoice]
      expect(results[:entries].first.invoices.first.invoice_lines.length).to eq 2

      expect(results[:entries].second).to eq entry2
      expect(results[:entries].second.invoices).to eq [invoice2]
      expect(results[:entries].second.invoices.first.invoice_lines.length).to eq 1
    end

    it "handles interleaved entry and invoice numbers, retaining the order the data was presented in the file" do
      row_data << ["54321", "CUST", "INV-456", "", "", "PART-1"]
      row_data << ["12345", "CUST", "INV-123", "", "", "PART-2"]
      row_data << ["54321", "CUST", "INV-123", "", "", "PART-2"]

      # The only data in the entry/invoice that matters is the file # and invoice number
      entry = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadEntry.new "12345", nil, []
      invoice = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoice.new "INV-123", nil, []
      item1 = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new
      item1.part_number = "PART-1"
      item2 = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new
      item2.part_number = "PART-2"

      # The only data in the entry/invoice that matters is the file # and invoice number
      entry2 = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadEntry.new "54321", nil, []
      invoice2 = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoice.new "INV-456", nil, []
      item3 = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new
      item3.part_number = "PART-1"
      invoice3 = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoice.new "INV-123", nil, []
      item4 = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new
      item4.part_number = "PART-2"


      expect(file_parser).to receive(:parse_entry_header).with(row_data[0]).and_return entry
      expect(file_parser).to receive(:parse_invoice_header).with(entry, row_data[0]).and_return invoice
      expect(file_parser).to receive(:parse_invoice_line).with(entry, invoice, row_data[0]).and_return item1
      expect(file_parser).to receive(:parse_invoice_line).with(entry, invoice, row_data[2]).and_return item2

      expect(file_parser).to receive(:parse_entry_header).with(row_data[1]).and_return entry2
      expect(file_parser).to receive(:parse_invoice_header).with(entry2, row_data[1]).and_return invoice2
      expect(file_parser).to receive(:parse_invoice_line).with(entry2, invoice2, row_data[1]).and_return item3
      expect(file_parser).to receive(:parse_invoice_header).with(entry2, row_data[3]).and_return invoice3
      expect(file_parser).to receive(:parse_invoice_line).with(entry2, invoice3, row_data[3]).and_return item4

      expect(subject).to receive(:foreach).and_return row_data
      expect(subject).to receive(:file_parser).with(file).and_return file_parser

      results = subject.parse file

      expect(results[:entries].size).to eq 2
      expect(results[:bad_row_count]).to eq 0
      expect(results[:generated_file_numbers]).to eq ["12345", "54321"]

      expect(results[:entries].first.invoices.size).to eq 1
      expect(results[:entries].first.invoices.first.invoice_lines.map(&:part_number)).to eq ["PART-1", "PART-2"]

      expect(results[:entries].second.invoices.size).to eq 2
      expect(results[:entries].second.invoices.first.invoice_lines.first.part_number).to eq "PART-1"
      expect(results[:entries].second.invoices.second.invoice_lines.first.part_number).to eq "PART-2"
    end

    it "marks rows missing any of file #, or invoice # as bad" do
      row_data << ["", "Cust", "INV-321"]
      row_data << ["12345" "CUST", ""]

      expect(subject).to receive(:foreach).and_return row_data
      expect(subject).to receive(:file_parser).with(file).and_return file_parser

      # The only data in the entry/invoice that matters is the file # and invoice number
      entry = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadEntry.new "12345", nil, []
      invoice = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoice.new "INV-123", nil, []

      expect(file_parser).to receive(:parse_entry_header).with(row_data[0]).and_return entry
      expect(file_parser).to receive(:parse_invoice_header).with(entry, row_data[0]).and_return invoice
      expect(file_parser).to receive(:parse_invoice_line).with(entry, invoice, row_data[0]).and_return OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new

      results = subject.parse file
      expect(results[:entries].size).to eq 1
      expect(results[:bad_row_count]).to eq 2
      expect(results[:generated_file_numbers]).to eq ["12345"]
    end

    it "marks rows the parser says are invalid as part of the bad row count" do
      expect(file_parser).to receive(:invalid_row?).with(row_data[0]).and_return true
      expect(subject).to receive(:foreach).and_return row_data
      expect(subject).to receive(:file_parser).with(file).and_return file_parser

      results = subject.parse file
      expect(results[:entries].size).to eq 0
      expect(results[:bad_row_count]).to eq 1
      expect(results[:generated_file_numbers]).to eq []
    end

    context "date handling" do
      # This is essentially testing a private method, but the parsing is important enough
      # that we're doing this via the top-level interface.

      context "with valid dates" do

        around :each do |example|
          # The code only accepts dates that are within 2 years from the current time..so use Timecop 
          # to freeze time, and allow us to use hardcoded values.
          Timecop.freeze(Time.zone.parse("2015-02-01 00:00")) do 
            example.run
          end
        end

        after :each do
          expect(subject).to receive(:foreach).and_return row_data

          results = subject.parse file
          expect(results[:entries].size).to eq 1
          i = results[:entries].first.invoices.first
          expect(i.invoice_date).to eq Date.new(2015, 2, 1)
        end

        it "parses m-d-yyyy values to date" do
          row_data[0][3] = "2-1-2015"
        end

        it "parses mm-dd-yyyy values to date" do
          row_data[0][3] = "02-01-2015"
        end

        it "parses yyyy-m-d values to date" do
          row_data[0][3] = "2015-2-1"
        end

        it "parses yymmdd values to date" do
          row_data[0][3] = "150201"
        end

        it "parses mmddyyyy values to date" do
          row_data[0][3] = "02012015"
        end

        it "parses yyyymmdd values to date" do
          row_data[0][3] = "20150201"
        end
      end

      context "with invalid dates" do
        before :each do 
          # This logic is only live for non-test envs, to avoid having to update dates in the test files after they get too old
          expect(MasterSetup).to receive(:test_env?).at_least(1).times.and_return false
        end

        after :each do
          expect(subject).to receive(:foreach).and_return row_data

          results = subject.parse file
          expect(results[:entries].size).to eq 1
          i = results[:entries].first.invoices.first
          expect(i.invoice_date).to eq nil
        end

        it "rejects dates that are more than 2 years old" do
          row_data[0][3] = (Time.zone.now - 3.years - 1.day).strftime "%Y-%m-%d"
        end

        it "rejects dates that are more than 2 years in the future" do
          row_data[0][3] = (Time.zone.now + 3.years + 1.day).strftime "%Y-%m-%d"
        end
      end
    end

    it "parses numeric values as string, stripping '.0' from numeric values" do
      # For values (like PO #'s) that are keyed as numeric values (12345), excel will store
      # them as actual numbers and return them to a program reading them as "12345.0".
      # We don't want that for the PO, we want 12345...so we want to maek sure the code is stripping
      # non-consequential trailing decimal points and zeros for string data.
      row_data[0][14] = 12.0
      expect(subject).to receive(:foreach).and_return row_data

      results = subject.parse file
      expect(results[:entries].size).to eq 1
      l = results[:entries].first.invoices.first.invoice_lines.first
      expect(l.po_number).to eq "12"
    end
  end

  describe "parse_and_send" do
    subject { described_class.new(nil) }
    let(:custom_file) { CustomFile.new attached_file_name: "test.csv" }

    it "parses file and uses generator to send it" do
      results = {entries: ["1"]}
      generator = double("kewill_generator")
      expect(generator).to receive(:generate_and_send).with results[:entries]
      expect(subject).to receive(:kewill_generator).and_return generator

      expect(subject).to receive(:parse).with(custom_file).and_return results

      expect(subject.parse_and_send custom_file).to eq results
    end

    it "doesn't call generator if there are no entries" do
      results = {entries: []}
      expect(subject).to receive(:parse).with(custom_file).and_return results
      expect(subject).not_to receive(:kewill_generator)
      expect(subject.parse_and_send custom_file).to eq results
    end
  end

  describe "process" do
    context "with parse mocking" do
      let(:custom_file) { CustomFile.new attached_file_name: "test.csv" }
      subject { described_class.new custom_file}
      let (:user) { Factory(:user) }

      it "parses the custom file and saves results to user messages" do
        results = {bad_row_count: 0, generated_file_numbers: ["12345"]}
        expect(subject).to receive(:parse_and_send).and_return results

        subject.process user

        expect(user.messages.size).to eq 1
        m = user.messages.first

        expect(m.subject).to eq "CI Load Processing Complete"
        expect(m.body).to eq "CI Load File 'test.csv' has finished processing.\nThe following file numbers are being transferred to Kewill Customs. They will be available shortly.\nFile Numbers: 12345"
      end

      it "displays error counts" do
        results = {bad_row_count: 2, generated_file_numbers: []}
        expect(subject).to receive(:parse_and_send).and_return results

        subject.process user

        expect(user.messages.size).to eq 1
        m = user.messages.first

        expect(m.subject).to eq "CI Load Processing Complete With Errors"
        expect(m.body).to eq "CI Load File 'test.csv' has finished processing.\nAll rows in the CI Load files must have values in the File #, Customer and Invoice # columns. 2 rows were missing one or more values in these columns and were skipped."
      end

      it "reports errors to user" do
        expect(subject).to receive(:parse_and_send).and_raise "Error"

        expect{subject.process user}.to raise_error(/Error/)

        expect(user.messages.size).to eq 1
        m = user.messages.first

        expect(m.subject).to eq "CI Load Processing Complete With Errors"
        expect(m.body).to eq "CI Load File 'test.csv' has finished processing.\n\nUnrecoverable errors were encountered while processing this file.  These errors have been forwarded to the IT department and will be resolved."
      end

      it "handles missing data error" do
        expect(subject).to receive(:parse_and_send).and_raise OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::MissingCiLoadDataError, "Bad Data"

        subject.process user

        expect(user.messages.size).to eq 1
        m = user.messages.first

        expect(m.subject).to eq "CI Load Processing Complete With Errors"
        expect(m.body).to eq "CI Load File 'test.csv' has finished processing.\n\nBad Data"
      end

      it "handles invalid file reader" do
        expect(subject).to receive(:parse_and_send).and_raise OpenChain::CustomHandler::CustomFileCsvExcelParser::NoFileReaderError, "No File Reader"

        subject.process user

        expect(user.messages.size).to eq 1
        m = user.messages.first

        expect(m.subject).to eq "CI Load Processing Complete With Errors"
        expect(m.body).to eq "CI Load File 'test.csv' has finished processing.\n\nNo File Reader\nPlease ensure the file is an Excel or CSV file and the filename ends with .xls, .xlsx or .csv."
      end
    end

    context "full integration" do
      let (:file) { CustomFile.new attached_file_name: "testing.csv" }
      let (:user) { Factory(:user) }
      subject { described_class.new file }

      before :each do
        @file = File.open("spec/fixtures/files/test_sheet_3.csv", "r")
      end

      after :each do
        @file.close
      end

      it "parses the custom file and saves results" do
        # This is primarily just a test to make sure the top level method is calling through to everything correctly
        expect_any_instance_of(OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator).to receive(:generate_and_send)
        # For some reason, respec won't let me add expectations on OpenChain::CustomHandler::CiLoadHandler::CsvParser.any_instance, they're not taking effect
        # so I'm mocking out the s3 call instead
        expect(OpenChain::S3).to receive(:download_to_tempfile).and_yield @file

        subject.process user

        expect(user.messages.size).to eq 1
      end
    end
  end


  describe "can_view?" do
    subject { described_class.new nil }

    context "alliance custom feature enabled" do

      before :each do
        ms = MasterSetup.new custom_features: "alliance"
        allow(MasterSetup).to receive(:get).and_return ms
      end

      it "allows master users to view" do
        expect(subject.can_view? Factory(:master_user)).to be_truthy
      end

      it "disallows regular user" do
        expect(subject.can_view? Factory(:user)).to be_falsey
      end
    end

    it "disallows access when alliance feature is not enabled" do
       ms = MasterSetup.new
       allow(MasterSetup).to receive(:get).and_return ms
       expect(subject.can_view? Factory(:master_user)).to be_falsey
    end
  end


  context "StandardCiLoadParser" do
    subject { OpenChain::CustomHandler::CiLoadHandler::StandardCiLoadParser.new nil }

    describe "invalid_row?" do
      it "validates a good row" do
        expect(subject.invalid_row? ["FILE", "CUST", "INV"]).to be_falsey
      end

      it "invalidates row missing file number" do
        expect(subject.invalid_row? [nil, "CUST", "INV"]).to be_truthy
      end

      it "invalidates row missing customer number" do
        expect(subject.invalid_row? ["FILE", "", "INV"]).to be_truthy
      end

      it "invalidates row missing invoice number" do
        expect(subject.invalid_row? ["File", "CUST", "   "]).to be_truthy
      end
    end

    describe "file_number_invoice_number_columns" do
      it "returns expected values" do
        expect(subject.file_number_invoice_number_columns).to eq({file_number: 0, invoice_number: 2})
      end
    end

    describe "parse_entry_header" do
      it "parses a row to an entry header object" do
        entry = subject.parse_entry_header [1234, "CUST"]
        expect(entry.file_number).to eq "1234"
        expect(entry.customer).to eq "CUST"
        expect(entry.invoices.length).to eq 0
      end

      it "parses a row to invoice header object" do
        invoice = subject.parse_invoice_header nil, [nil, nil, "INV", "2016-02-01"]
        expect(invoice.invoice_number).to eq "INV"
        expect(invoice.invoice_date).to eq Date.new(2016, 2, 1)
        expect(invoice.invoice_lines.length).to eq 0
      end

      it 'parses a row to invoice line object' do
        l = subject.parse_invoice_line nil, nil, row_data.first

        expect(l.part_number).to eq "PART-1"
        expect(l.country_of_origin).to eq "US"
        expect(l.gross_weight).to eq BigDecimal("50.5")
        expect(l.pieces).to eq BigDecimal("12")
        expect(l.hts).to eq "1234567890"
        expect(l.foreign_value).to eq BigDecimal("22.50")
        expect(l.quantity_1).to eq BigDecimal("10")
        expect(l.quantity_2).to eq BigDecimal("35")
        expect(l.po_number).to eq "Purchase Order"
        expect(l.first_sale).to eq BigDecimal("21.50")
        expect(l.department).to eq BigDecimal("19")
        expect(l.spi).to eq "A+"
        expect(l.add_to_make_amount).to eq BigDecimal("123.45")
        expect(l.non_dutiable_amount).to be_nil
        expect(l.cotton_fee_flag).to eq "N"
        expect(l.mid).to eq "MID12345"
        expect(l.cartons).to eq BigDecimal("12")
        expect(l.buyer_customer_number).to eq "BuyerCustNo"
        expect(l.seller_mid).to eq "SellerMID"
        expect(l.spi2).to eq "X"
      end

      it "handles negative value in col 17 as non-dutiable charge" do
        row_data.first[17] = "-123.45"

        l = subject.parse_invoice_line nil, nil, row_data.first

        expect(l.add_to_make_amount).to be_nil
        expect(l.non_dutiable_amount).to eq BigDecimal("123.45")
      end
    end
  end

  context "HmCiLoadParser" do
    subject { OpenChain::CustomHandler::CiLoadHandler::HmCiLoadParser.new nil }

    describe "invalid_row?" do
      it "validates a good row" do
        expect(subject.invalid_row? ["FILE", nil, "INV"]).to be_falsey
      end

      it "invalidates row missing file number" do
        expect(subject.invalid_row? [nil, nil, "INV"]).to be_truthy
      end

      it "invalidates row missing invoice number" do
        expect(subject.invalid_row? ["File", nil, "   "]).to be_truthy
      end
    end

    describe "file_number_invoice_number_columns" do
      it "returns expected values" do
        expect(subject.file_number_invoice_number_columns).to eq({file_number: 0, invoice_number: 2})
      end
    end

    describe "parse_entry_header" do
      it "parses a row to an entry header object" do
        entry = subject.parse_entry_header [1234]
        expect(entry.file_number).to eq "1234"
        expect(entry.customer).to eq "HENNE"
        expect(entry.invoices.length).to eq 0
      end

      it "parses a row to invoice header object" do
        invoice = subject.parse_invoice_header nil, [nil, nil, "INV", nil, "-1.23", "3.45"]
        expect(invoice.invoice_number).to eq "INV"
        expect(invoice.invoice_date).to eq nil
        expect(invoice.non_dutiable_amount).to eq BigDecimal("1.23") # validate we're storing the abs value
        expect(invoice.add_to_make_amount).to eq BigDecimal("3.45")
        expect(invoice.invoice_lines.length).to eq 0
      end

      it 'parses a row to invoice line object' do
        l = subject.parse_invoice_line nil, nil, [nil, nil, nil, "1.23", nil, nil, nil, "1234567890", "CN", "5", "10", "2", "100", "MID", "PART", "10", "BuyerCustNo", "SellerMID", "Cotton"]

        expect(l.country_of_origin).to eq "CN"
        expect(l.gross_weight).to eq BigDecimal("100")
        expect(l.hts).to eq "1234567890"
        expect(l.foreign_value).to eq BigDecimal("1.23")
        expect(l.quantity_1).to eq BigDecimal("5")
        expect(l.quantity_2).to eq BigDecimal("10")
        expect(l.mid).to eq "MID"
        expect(l.cartons).to eq BigDecimal("2")
        expect(l.part_number).to eq "PART"
        expect(l.pieces).to eq BigDecimal("10")
        expect(l.buyer_customer_number).to eq "BuyerCustNo"
        expect(l.seller_mid).to eq "SellerMID"
        expect(l.cotton_fee_flag).to eq "Cotton"
      end
    end
  end

  describe "file_parser" do

    subject {
      described_class.new nil
    }

    it "returns HM parser for files named like HMCI" do
      expect(subject.file_parser(CustomFile.new attached_file_name: "HmCi.csv")).to be_a OpenChain::CustomHandler::CiLoadHandler::HmCiLoadParser
    end

    it "returns standard parser for all other files" do
      expect(subject.file_parser(CustomFile.new attached_file_name: "other.csv")).to be_a OpenChain::CustomHandler::CiLoadHandler::StandardCiLoadParser
    end
  end

  describe "valid_file?" do
    subject { described_class }

    it "allows csv files" do
      expect(subject.valid_file? "test.csv").to eq true
    end

    it "allows xls files" do
      expect(subject.valid_file? "test.xls").to eq true
    end

    it "allows xlsx files" do
      expect(subject.valid_file? "test.xlsx").to eq true
    end

    it "disallows other files" do
      expect(subject.valid_file? "test.xlsm").to eq false
    end
  end
end
