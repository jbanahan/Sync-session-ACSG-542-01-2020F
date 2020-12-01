describe OpenChain::CustomHandler::CiLoadHandler do

  let (:row_data) do
    [
      [
        "12345", "CUST", "INV-123", "2015-01-01", "US", "PART-1", 12.0, "MID12345", "1234.56.7890",
        "N", 22.50, 10, 35, 50.5, "Purchase Order", 12, "21.50", "123.45", "19", "A+", "BuyerCustNo", "SellerMID", "X"
      ]
    ]
  end

  describe "parse" do

    subject do
      described_class.new file
    end

    let (:file) do
      CustomFile.new attached_file_name: "testing.csv"
    end

    let (:file_parser) do
      d = instance_double(OpenChain::CustomHandler::Vandegrift::StandardCiLoadParser)
      allow(d).to receive(:file_number_invoice_number_columns).and_return file_number: 0, invoice_number: 2
      allow(d).to receive(:invalid_row?).and_return false

      d
    end

    it "parses a file into kewill invoice generator objects" do
      expect(subject).to receive(:foreach).with(file, skip_headers: true, skip_blank_lines: true).and_return row_data
      expect(subject).to receive(:file_parser).with(file).and_return file_parser
      # The only data in the entry/invoice that matters is the file # and invoice number
      entry = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadEntry.new "12345", nil, []
      invoice = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoice.new "INV-123", nil, []

      expect(file_parser).to receive(:parse_entry_header).with(row_data[0]).and_return entry
      expect(file_parser).to receive(:parse_invoice_header).with(entry, row_data[0]).and_return invoice
      expect(file_parser).to receive(:parse_invoice_line).with(entry, invoice, row_data[0]).and_return OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new # rubocop:disable Layout/LineLength

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
      expect(file_parser).to receive(:parse_invoice_line).with(entry, invoice, row_data[0]).and_return OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new # rubocop:disable Layout/LineLength
      expect(file_parser).to receive(:parse_invoice_line).with(entry, invoice, row_data[1]).and_return OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new # rubocop:disable Layout/LineLength

      expect(file_parser).to receive(:parse_entry_header).with(row_data[2]).and_return entry2
      expect(file_parser).to receive(:parse_invoice_header).with(entry2, row_data[2]).and_return invoice2
      expect(file_parser).to receive(:parse_invoice_line).with(entry2, invoice2, row_data[2]).and_return OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new # rubocop:disable Layout/LineLength

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
      row_data << ["12345", "CUST", ""]

      expect(subject).to receive(:foreach).and_return row_data
      expect(subject).to receive(:file_parser).with(file).and_return file_parser

      # The only data in the entry/invoice that matters is the file # and invoice number
      entry = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadEntry.new "12345", nil, []
      invoice = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoice.new "INV-123", nil, []

      expect(file_parser).to receive(:parse_entry_header).with(row_data[0]).and_return entry
      expect(file_parser).to receive(:parse_invoice_header).with(entry, row_data[0]).and_return invoice
      expect(file_parser).to receive(:parse_invoice_line).with(entry, invoice, row_data[0]).and_return OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new # rubocop:disable Layout/LineLength

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

        around do |example|
          # The code only accepts dates that are within 2 years from the current time..so use Timecop
          # to freeze time, and allow us to use hardcoded values.
          Timecop.freeze(Time.zone.parse("2015-02-01 00:00")) do
            example.run
          end
        end

        after do
          # rubocop:disable RSpec/ExpectInHook
          expect(subject).to receive(:foreach).and_return row_data

          results = subject.parse file
          expect(results[:entries].size).to eq 1
          i = results[:entries].first.invoices.first
          expect(i.invoice_date).to eq Date.new(2015, 2, 1)
          # rubocop:enable RSpec/ExpectInHook
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
        # rubocop:disable RSpec/ExpectInHook
        before do
          # This logic is only live for non-test envs, to avoid having to update dates in the test files after they get too old
          expect(MasterSetup).to receive(:test_env?).at_least(:once).and_return false
        end

        after do
          expect(subject).to receive(:foreach).and_return row_data

          results = subject.parse file
          expect(results[:entries].size).to eq 1
          i = results[:entries].first.invoices.first
          expect(i.invoice_date).to eq nil
        end
        # rubocop:enable RSpec/ExpectInHook

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
      generator = instance_double(OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator)
      expect(generator).to receive(:generate_and_send).with results[:entries]
      expect(subject).to receive(:kewill_generator).and_return generator

      expect(subject).to receive(:parse).with(custom_file).and_return results

      expect(subject.parse_and_send(custom_file)).to eq results
    end

    it "doesn't call generator if there are no entries" do
      results = {entries: []}
      expect(subject).to receive(:parse).with(custom_file).and_return results
      expect(subject).not_to receive(:kewill_generator)
      expect(subject.parse_and_send(custom_file)).to eq results
    end
  end

  describe "process" do
    context "with parse mocking" do
      subject { described_class.new custom_file}

      let(:custom_file) { CustomFile.new attached_file_name: "test.csv" }

      let (:user) { FactoryBot(:user) }

      it "parses the custom file and saves results to user messages" do
        results = {bad_row_count: 0, generated_file_numbers: ["12345"]}
        expect(subject).to receive(:parse_and_send).and_return results

        subject.process user

        expect(user.messages.size).to eq 1
        m = user.messages.first

        expect(m.subject).to eq "CI Load Processing Complete"
        expect(m.body).to eq "CI Load File 'test.csv' has finished processing.\nThe following file numbers are being transferred to Kewill Customs. They will be available shortly.\nFile Numbers: 12345" # rubocop:disable Layout/LineLength
      end

      it "displays error counts" do
        results = {bad_row_count: 2, generated_file_numbers: []}
        expect(subject).to receive(:parse_and_send).and_return results

        subject.process user

        expect(user.messages.size).to eq 1
        m = user.messages.first

        expect(m.subject).to eq "CI Load Processing Complete With Errors"
        expect(m.body).to eq "CI Load File 'test.csv' has finished processing.\nAll rows in the CI Load files must have values in the File #, Customer and Invoice # columns. 2 rows were missing one or more values in these columns and were skipped." # rubocop:disable Layout/LineLength
      end

      it "reports errors to user" do
        expect(subject).to receive(:parse_and_send).and_raise "Error"

        expect {subject.process user}.to raise_error(/Error/)

        expect(user.messages.size).to eq 1
        m = user.messages.first

        expect(m.subject).to eq "CI Load Processing Complete With Errors"
        expect(m.body).to eq "CI Load File 'test.csv' has finished processing.\n\nUnrecoverable errors were encountered while processing this file."
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
        expect(m.body).to eq "CI Load File 'test.csv' has finished processing.\n\nNo File Reader\nPlease ensure the file is an Excel or CSV file and the filename ends with .xls, .xlsx or .csv." # rubocop:disable Layout/LineLength
      end
    end

    context "full integration" do
      subject { described_class.new file }

      let (:file) { CustomFile.new attached_file_name: "testing.csv" }
      let (:user) { FactoryBot(:user) }
      let (:csv_file) { File.open("spec/fixtures/files/test_sheet_3.csv", "r") }

      after do
        csv_file.close
      end

      it "parses the custom file and saves results" do
        # This is primarily just a test to make sure the top level method is calling through to everything correctly
        expect_any_instance_of(OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator).to receive(:generate_and_send)
        # For some reason, respec won't let me add expectations on OpenChain::CustomHandler::CiLoadHandler::CsvParser.any_instance, they're not taking effect
        # so I'm mocking out the s3 call instead
        expect(OpenChain::S3).to receive(:download_to_tempfile).and_yield csv_file

        subject.process user

        expect(user.messages.size).to eq 1
      end
    end
  end

  describe "can_view?" do
    subject { described_class.new nil }

    context "Kewill CI Upload custom feature enabled" do

      before do
        ms = MasterSetup.new custom_features: "Kewill CI Upload"
        allow(MasterSetup).to receive(:get).and_return ms
      end

      it "allows master users to view" do
        expect(subject.can_view?(FactoryBot(:master_user))).to be_truthy
      end

      it "disallows regular user" do
        expect(subject.can_view?(FactoryBot(:user))).to be_falsey
      end
    end

    it "disallows access when Kewill CI Upload feature is not enabled" do
       ms = MasterSetup.new
       allow(MasterSetup).to receive(:get).and_return ms
       expect(subject.can_view?(FactoryBot(:master_user))).to be_falsey
    end
  end

  describe "file_parser" do

    subject do
      described_class.new nil
    end

    it "returns HM parser for files named like HMCI" do
      expect(subject.file_parser(CustomFile.new(attached_file_name: "HmCi.csv"))).to be_a OpenChain::CustomHandler::Vandegrift::HmCiLoadParser
    end

    it "returns standard parser for all other files" do
      expect(subject.file_parser(CustomFile.new(attached_file_name: "other.csv"))).to be_a OpenChain::CustomHandler::Vandegrift::StandardCiLoadParser
    end
  end

  describe "valid_file?" do
    subject { described_class }

    it "allows csv files" do
      expect(subject.valid_file?("test.csv")).to eq true
    end

    it "allows xls files" do
      expect(subject.valid_file?("test.xls")).to eq true
    end

    it "allows xlsx files" do
      expect(subject.valid_file?("test.xlsx")).to eq true
    end

    it "disallows other files" do
      expect(subject.valid_file?("test.xlsm")).to eq false
    end
  end

  describe "handle_uncaught_error" do
    subject { described_class.new custom_file }

    let (:custom_file) do
      cf = CustomFile.new attached_file_name: "testing.csv"
      allow(cf).to receive(:id).and_return 1
      cf
    end

    let (:error) { StandardError.new "Error Message" }
    let (:now) { Time.zone.now }

    it "logs the error and updates the custom file" do
      expect(error).to receive(:log_me).with ["Custom File ID: 1"]
      expect(custom_file).to receive(:update).with(error_at: now,  error_message: "Error Message")

      Timecop.freeze(now) { subject. handle_uncaught_error nil, error }
    end
  end
end
