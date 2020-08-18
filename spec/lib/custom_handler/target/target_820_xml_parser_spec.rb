describe OpenChain::CustomHandler::Target::Target820XmlParser do
  let (:test_data) { IO.read('spec/fixtures/files/target_820.xml') }

  describe "parse" do
    let (:log) { InboundFile.new }

    before do
      allow(subject).to receive(:inbound_file).and_return log
    end

    def make_document xml_str
      doc = Nokogiri::XML xml_str
      doc.remove_namespaces!
      doc
    end

    it "parses XML data to a spreadsheet and emails it" do
      target = with_customs_management_id(Factory(:importer), "TARGEN")
      Factory(:mailing_list, company: target, system_code: "Target 820 Report", email_addresses: "a@b.com,c@d.com")

      Factory(:entry, broker_reference: "23920", entry_number: "31625496331", source_system: Entry::KEWILL_SOURCE_SYSTEM, customer_number: "TARGEN")

      Timecop.freeze(make_eastern_date(2019, 9, 30)) do
        expect(subject.parse(make_document(test_data))).to be_nil
      end

      expect(ActionMailer::Base.deliveries.length).to eq 1
      mail = ActionMailer::Base.deliveries.first
      expect(mail.to).to eq ["a@b.com", "c@d.com"]
      expect(mail.subject).to eq "Target 820 Report"
      expect(mail.body).to include "Attached is a report based on an 820 receipt from Target."

      att = mail.attachments["Target_820_Report_2019-09-30.xlsx"]
      expect(att).not_to be_nil
      reader = XlsxTestReader.new(StringIO.new(att.read)).raw_workbook_data
      expect(reader.length).to eq 1

      sheet = reader["Data"]
      expect(sheet).not_to be_nil
      expect(sheet.length).to eq 11
      expect(sheet[0]).to eq ["TGMI", nil, nil, nil, nil, nil, nil]
      expect(sheet[1]).to eq ["Broker ACH Detail Report", nil, nil, nil, nil, nil, nil]
      expect(sheet[2]).to eq []
      expect(sheet[3]).to eq []
      expect(sheet[4]).to eq []
      expect(sheet[5]).to eq ["Payee Name", "Invoice #", "Entry #", "Payment Ref #", "Expense Code",
                              "Invoice Date", "Payment Date", "Payment Amount", "Invoice Amount"]
      expect(sheet[6]).to eq ["EVERGREEN AMERICA CORPORA", "23920", "31625496331",
                              "TGT68668", "BRO", Date.new(2019, 11, 10), Date.new(2019, 11, 8), 163.37, 16.33]
      expect(sheet[7]).to eq ["EVERGREEN AMERICA CORPORA", "23920", "31625496331",
                              "TGT68668", "BRO", Date.new(2019, 11, 11), Date.new(2019, 11, 8), 2383.63, 238.36]
      expect(sheet[8]).to eq []
      expect(sheet[9]).to eq ["Total Payment Amount VANDEGRIFT FORWARDING", nil, nil, nil, nil, nil, nil, 2547.0]
      expect(sheet[10]).to eq ["Run Date: 09-30-2019", nil, nil, nil, nil, nil, nil]

      expect(log).to have_identifier(:payment_reference_number, "TGT68668")
    end

    it "ignores lines with no payment amount" do
      # This is the payment amount for what would be the first line.  It should be skipped, and the resulting report
      # should contain only one data line rather than two.
      test_data.gsub!("163.37", "")

      Factory(:entry, broker_reference: "23920", entry_number: "31625496331", source_system: Entry::KEWILL_SOURCE_SYSTEM, customer_number: "TARGEN")

      target = with_customs_management_id(Factory(:importer), "TARGEN")
      Factory(:mailing_list, company: target, system_code: "Target 820 Report", email_addresses: "a@b.com,c@d.com")

      Timecop.freeze(make_eastern_date(2019, 9, 30)) do
        expect(subject.parse(make_document(test_data))).to be_nil
      end

      expect(ActionMailer::Base.deliveries.length).to eq 1
      mail = ActionMailer::Base.deliveries.first
      expect(mail.to).to eq ["a@b.com", "c@d.com"]
      expect(mail.subject).to eq "Target 820 Report"
      expect(mail.body).to include "Attached is a report based on an 820 receipt from Target."

      att = mail.attachments["Target_820_Report_2019-09-30.xlsx"]
      expect(att).not_to be_nil
      reader = XlsxTestReader.new(StringIO.new(att.read)).raw_workbook_data
      expect(reader.length).to eq 1

      sheet = reader["Data"]
      expect(sheet).not_to be_nil
      expect(sheet.length).to eq 10
      expect(sheet[0]).to eq ["TGMI", nil, nil, nil, nil, nil, nil]
      expect(sheet[1]).to eq ["Broker ACH Detail Report", nil, nil, nil, nil, nil, nil]
      expect(sheet[2]).to eq []
      expect(sheet[3]).to eq []
      expect(sheet[4]).to eq []
      expect(sheet[5]).to eq ["Payee Name", "Invoice #", "Entry #", "Payment Ref #", "Expense Code",
                              "Invoice Date", "Payment Date", "Payment Amount", "Invoice Amount"]
      expect(sheet[6]).to eq ["EVERGREEN AMERICA CORPORA", "23920", "31625496331",
                              "TGT68668", "BRO", Date.new(2019, 11, 11), Date.new(2019, 11, 8), 2383.63, 238.36]
      expect(sheet[7]).to eq []
      expect(sheet[8]).to eq ["Total Payment Amount VANDEGRIFT FORWARDING", nil, nil, nil, nil, nil, nil, 2383.63]
      expect(sheet[9]).to eq ["Run Date: 09-30-2019", nil, nil, nil, nil, nil, nil]
    end

    it "raises error if mailing list not found" do
      with_customs_management_id(Factory(:importer), "TARGEN")

      expect { subject.parse(make_document(test_data)) }.to raise_error("No mailing list exists for 'Target 820 Report' system code.")

      expect(ActionMailer::Base.deliveries.length).to eq 0

      expect(log).to have_error_message("No mailing list exists for 'Target 820 Report' system code.")
    end

    it "raises error if Target importer not found" do
      expect { subject.parse(make_document(test_data)) }.to raise_error("No importer account exists with 'TARGEN' account number.")

      expect(ActionMailer::Base.deliveries.length).to eq 0

      expect(log).to have_error_message("No importer account exists with 'TARGEN' account number.")
    end

    def make_utc_date year, month, day
      ActiveSupport::TimeZone["UTC"].parse("#{year}-#{month}-#{day} 16:00")
    end

    def make_eastern_date year, month, day
      dt = make_utc_date(year, month, day)
      dt = dt.in_time_zone(ActiveSupport::TimeZone["America/New_York"])
      dt
    end
  end

  describe "parse_file" do
    it "calls parse method" do
      expect_any_instance_of(described_class).to receive(:parse).with(instance_of(Nokogiri::XML::Document), { A: "B" })

      described_class.parse_file test_data, nil, { A: "B" }
    end
  end
end