require 'spec_helper'

describe OpenChain::CustomHandler::CiLoadHandler do

  describe "parse" do
    let (:row_data) {
      [
        ["File #", "Customer", "Invoice #", "Invoice Date", "C/O", "Part #", "Pieces", "MID", "HTS #", "Cotton Fee", "Value", "Qty 1", "Qty 2", "Gross Weight", "PO #", "Cartons", "First Sale", "NDC/MMV", "department", "SPI"], # Column Headers...don't care about.
        ["12345", "CUST", "INV-123", "2015-01-01", "US", "PART-1", 12.0, "MID12345", "1234.56.7890", "N", 22.50, 10, 35, 50.5, "Purchase Order", 12, "21.50", "123.45", "19", "A+"]
      ]
    }

    let (:parser) {
      p = double("CiLoadParser")
      p.should_receive(:parse_file).and_return @row_data
      p
    }

    let (:file) {
      CustomFile.new attached_file_name: "testing.csv"
    }

    subject {
      s = described_class.new file
      s.stub(:file_parser).with(file).and_return parser
      s
    }

    it "parses a file into kewill invoice generator objects" do
      @row_data = row_data
      results = subject.parse file
      expect(results[:entries].size).to eq 1
      expect(results[:bad_row_count]).to eq 0
      expect(results[:generated_file_numbers]).to eq ["12345"]

      e = results[:entries].first
      expect(e.file_number).to eq "12345"
      expect(e.customer).to eq "CUST"
      expect(e.invoices.length).to eq 1

      i = e.invoices.first
      expect(i.invoice_number).to eq "INV-123"
      expect(i.invoice_date).to eq Date.new(2015,1,1)
      expect(i.invoice_lines.length).to eq 1

      l = i.invoice_lines.first
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
      expect(l.ndc_mmv).to eq BigDecimal("123.45")
      expect(l.cotton_fee_flag).to eq "N"
      expect(l.mid).to eq "MID12345"
      expect(l.cartons).to eq BigDecimal("12")
    end

    it "parses multiple files and invoices" do
      data = row_data
      data << ["12345", "CUST", "INV-123", "", "", "PART-2"]
      data << ["54321", "CUST", "INV-321", "", "", "PART-1"]
      @row_data = row_data

      results = subject.parse file

      expect(results[:entries].size).to eq 2
      expect(results[:bad_row_count]).to eq 0
      expect(results[:generated_file_numbers]).to eq ["12345", "54321"]
    end

    it "handles interleaved entry and invoice numbers, retaining the order the data was presented in the file" do
      data = row_data
      data << ["54321", "CUST", "INV-456", "", "", "PART-1"]
      data << ["12345", "CUST", "INV-123", "", "", "PART-2"]
      data << ["54321", "CUST", "INV-123", "", "", "PART-2"]

      @row_data = row_data

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

    it "skips blank rows in the file, marks rows missing any of file #, customer, or invoice # as bad" do
      data = row_data
      data << ["12345", "CUST", "INV-123", "", "", "PART-2"]
      data << ["", "  ", nil]
      data << ["54321", "CUST", "INV-321", "", "", "PART-1"]
      @row_data = row_data

      results = subject.parse file

      expect(results[:entries].size).to eq 2
      expect(results[:bad_row_count]).to eq 0
      expect(results[:generated_file_numbers]).to eq ["12345", "54321"]
    end

    it "marks rows missing any of file #, customer, or invoice # as bad" do
      data = row_data
      data << ["", "Cust", "INV-321"]
      data << ["12345", "", "INV-321"]
      data << ["12345" "CUST", ""]

      @row_data = row_data

      results = subject.parse file
      expect(results[:entries].size).to eq 1
      expect(results[:bad_row_count]).to eq 3
      expect(results[:generated_file_numbers]).to eq ["12345"]
    end

    it "parses m-d-yyyy values to date" do
      row_data[1][3] = "2-1-2015"
      @row_data = row_data

      results = subject.parse file
      expect(results[:entries].size).to eq 1
      i = results[:entries].first.invoices.first
      expect(i.invoice_date).to eq Date.new(2015, 2, 1)
    end

    it "parses mm-dd-yyyy values to date" do
      row_data[1][3] = "02-01-2015"
      @row_data = row_data

      results = subject.parse file
      expect(results[:entries].size).to eq 1
      i = results[:entries].first.invoices.first
      expect(i.invoice_date).to eq Date.new(2015, 2, 1)
    end

    it "parses yyyy-m-d values to date" do
      row_data[1][3] = "2015-2-1"
      @row_data = row_data

      results = subject.parse file
      expect(results[:entries].size).to eq 1
      i = results[:entries].first.invoices.first
      expect(i.invoice_date).to eq Date.new(2015, 2, 1)
    end

    it "parses yymmdd values to date" do
      row_data[1][3] = "150201"
      @row_data = row_data

      results = subject.parse file
      expect(results[:entries].size).to eq 1
      i = results[:entries].first.invoices.first
      expect(i.invoice_date).to eq Date.new(2015, 2, 1)
    end

    it "parses mmddyyyy values to date" do
      row_data[1][3] = "02012015"
      @row_data = row_data

      results = subject.parse file
      expect(results[:entries].size).to eq 1
      i = results[:entries].first.invoices.first
      expect(i.invoice_date).to eq Date.new(2015, 2, 1)
    end

    it "parses yyyymmdd values to date" do
      row_data[1][3] = "02012015"
      @row_data = row_data

      results = subject.parse file
      expect(results[:entries].size).to eq 1
      i = results[:entries].first.invoices.first
      expect(i.invoice_date).to eq Date.new(2015, 2, 1)
    end

    it "rejects dates that are more than 2 years old" do
      row_data[1][3] = (Time.zone.now - 3.years - 1.day).strftime "%Y-%m-%d"
      @row_data = row_data

      results = subject.parse file
      expect(results[:entries].size).to eq 1
      i = results[:entries].first.invoices.first
      expect(i.invoice_date).to eq nil
    end

    it "rejects dates that are more than 2 years in the future" do
      row_data[1][3] = (Time.zone.now + 3.years + 1.day).strftime "%Y-%m-%d"
      @row_data = row_data

      results = subject.parse file
      expect(results[:entries].size).to eq 1
      i = results[:entries].first.invoices.first
      expect(i.invoice_date).to eq nil
    end

    it "parses numeric values as string, stripping '.0' from numeric values" do
      # For values (like PO #'s) that are keyed as numeric values (12345), excel will store
      # them as actual numbers and return them to a program reading them as "12345.0".  
      # We don't want that for the PO, we want 12345...so we want to maek sure the code is stripping
      # non-consequential trailing decimal points and zeros for string data.
      row_data[1][14] = 12.0
      @row_data = row_data

      results = subject.parse file
      expect(results[:entries].size).to eq 1
      l = results[:entries].first.invoices.first.invoice_lines.first
      expect(l.po_number).to eq "12"
    end
  end

  describe "file_parser" do

    subject { described_class.new(nil) }

    it "uses csv parser when filename ends w/ .csv" do
      p = subject.file_parser CustomFile.new(attached_file_name: "file.csv")
      expect(p.class.name).to eq "OpenChain::CustomHandler::CiLoadHandler::CsvParser"
    end

    it "uses csv parser when filename ends w/ .txt" do
      p = subject.file_parser CustomFile.new(attached_file_name: "file.txt")
      expect(p.class.name).to eq "OpenChain::CustomHandler::CiLoadHandler::CsvParser"
    end

    it "uses excel parser when filename ends w/ .xls" do
      p = subject.file_parser CustomFile.new(attached_file_name: "file.xls")
      expect(p.class.name).to eq "OpenChain::CustomHandler::CiLoadHandler::ExcelParser"
    end

    it "uses csv parser when filename ends w/ .xlsx" do
      p = subject.file_parser CustomFile.new(attached_file_name: "file.xlsx")
      expect(p.class.name).to eq "OpenChain::CustomHandler::CiLoadHandler::ExcelParser"
    end
  end

  describe "parse file" do

    subject { described_class.new(nil) }

    context "csv file" do

      let(:custom_file) { CustomFile.new attached_file_name: "test.csv" }
      let(:parser) { subject.file_parser custom_file }

      before :each do
        @file = File.open("spec/fixtures/files/test_sheet_3.csv", "r")
      end

      after :each do
        @file.close
      end

      it "reads a csv file and returns all rows from the file" do
        custom_file.should_receive(:bucket).and_return "bucket"
        custom_file.should_receive(:path).and_return "path"

        OpenChain::S3.should_receive(:download_to_tempfile).with("bucket", "path").and_yield @file

        rows = parser.parse_file custom_file

        expect(rows.length).to eq 8
        expect(rows.first).to eq ["First Column","Second Column","Third Column"]
      end
    end

    context "xls file" do
      let(:custom_file) { CustomFile.new attached_file_name: "test.xls" }
      let(:parser) { subject.file_parser custom_file }

      it "uses xlclient to read file" do
        custom_file.should_receive(:path).and_return "test.xls"
        rows = [["1", "2", "3"], ["4", "5", "6"]]
        OpenChain::XLClient.any_instance.should_receive(:all_row_values).and_return rows
        parser_rows = parser.parse_file custom_file
        expect(parser_rows).to eq rows
      end
    end
  end

  describe "parse_and_send" do
    subject { described_class.new(nil) }
    let(:custom_file) { CustomFile.new attached_file_name: "test.csv" }

    it "parses file and uses generator to send it" do
      results = {entries: ["1"]}
      generator = double("kewill_generator")
      generator.should_receive(:generate_and_send).with results[:entries]
      subject.should_receive(:kewill_generator).and_return generator

      subject.should_receive(:parse).with(custom_file).and_return results

      expect(subject.parse_and_send custom_file).to eq results
    end

    it "doesn't call generator if there are no entries" do
      results = {entries: []}
      subject.should_receive(:parse).with(custom_file).and_return results
      subject.should_not_receive(:kewill_generator)
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
        subject.should_receive(:parse_and_send).and_return results

        subject.process user

        expect(user.messages.size).to eq 1
        m = user.messages.first

        expect(m.subject).to eq "CI Load Processing Complete"
        expect(m.body).to eq "CI Load File 'test.csv' has finished processing.\nThe following file numbers are being transferred to Kewill Customs. They will be available shortly.\nFile Numbers: 12345"
      end

      it "displays error counts" do
        results = {bad_row_count: 2, generated_file_numbers: []}
        subject.should_receive(:parse_and_send).and_return results

        subject.process user

        expect(user.messages.size).to eq 1
        m = user.messages.first

        expect(m.subject).to eq "CI Load Processing Complete With Errors"
        expect(m.body).to eq "CI Load File 'test.csv' has finished processing.\nAll rows in the CI Load files must have values in the File #, Customer and Invoice # columns. 2 rows were missing one or more values in these columns and were skipped."
      end

      it "reports errors to user" do
        subject.should_receive(:parse_and_send).and_raise "Error"

        expect{subject.process user}.to raise_error

        expect(user.messages.size).to eq 1
        m = user.messages.first

        expect(m.subject).to eq "CI Load Processing Complete With Errors"
        expect(m.body).to eq "CI Load File 'test.csv' has finished processing.\n\nUnrecoverable errors were encountered while processing this file.  These errors have been forwarded to the IT department and will be resolved."
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
        OpenChain::CustomHandler::KewillCommercialInvoiceGenerator.any_instance.should_receive(:generate_and_send)
        # For some reason, respec won't let me add expectations on OpenChain::CustomHandler::CiLoadHandler::CsvParser.any_instance, they're not taking effect
        # so I'm mocking out the s3 call instead
        OpenChain::S3.should_receive(:download_to_tempfile).and_yield @file

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
        MasterSetup.stub(:get).and_return ms
      end

      it "allows master users to view" do
        expect(subject.can_view? Factory(:master_user)).to be_true
      end

      it "disallows regular user" do
        expect(subject.can_view? Factory(:user)).to be_false
      end
    end
    
    it "disallows access when alliance feature is not enabled" do
       ms = MasterSetup.new
       MasterSetup.stub(:get).and_return ms
       expect(subject.can_view? Factory(:master_user)).to be_false
    end
  end
end