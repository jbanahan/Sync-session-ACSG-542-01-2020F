describe OpenChain::Report::AllianceWebtrackingMonitorReport do

  subject { described_class }

  describe "process_alliance_query_details" do

    before :each do
      @existing_entry = Factory(:entry, broker_reference: "existing", source_system: "Alliance", last_exported_from_source: Time.zone.parse("2018-04-01"))
      @existing_invoice = Factory(:broker_invoice, entry: @existing_entry)
    end

    it "parses query results and emails report about missing file numbers" do
      results = [
        ['file1', '', '20141001', '20141007'],
        [@existing_entry.broker_reference, '', '', ''],
        ['file1', 'invoice1', '20141001', '20141007', '20141006'],
        ['', @existing_invoice.invoice_number.to_s]
      ]

      expect(OpenChain::KewillSqlProxyClient).to receive(:delay).and_return OpenChain::KewillSqlProxyClient
      expect(OpenChain::KewillSqlProxyClient).to receive(:request_entry_data).with("file1")

      subject.process_alliance_query_details results.to_json

      expect(OpenMailer.deliveries.length).to eq 1

      m = OpenMailer.deliveries.first
      expect(m.to).to eq ["support@vandegriftinc.com"]
      expect(m.subject).to eq "[VFI Track] Missing Entry Files"
      expect(m.body.raw_source).to include "Attached is a listing of 1 Entry and 1 Invoice missing from VFI Track. Please ensure these files get pushed from Alliance to VFI Track."

      attachment = m.attachments.first
      expect(attachment).not_to be_nil

      io = StringIO.new(attachment.read)
      wb = Spreadsheet.open(io)
      sheet = wb.worksheet 0
      expect(sheet.rows.length).to eq 2
      expect(sheet.name).to eq "Missing File #s"
      expect(sheet.row(0)).to eq ["File #", "File Logged Date", 'Invoice Prepared Date']
      expect(sheet.row(1)).to eq ["file1", '2014-10-01', '2014-10-07']

      sheet = wb.worksheet 1
      expect(sheet.rows.length).to eq 2
      expect(sheet.name).to eq "Missing Invoice #s"
      expect(sheet.row(0)).to eq ["Invoice #", "Invoice Date"]
      expect(sheet.row(1)).to eq ["invoice1", "2014-10-06"]
    end

    it "doesn't send an email if the entry has been purged" do
      results = [
        ['file1', '', '20141001', '20141007'],
        [@existing_entry.broker_reference, '', '', ''],
        ['file1', 'invoice1', '20141001', '20141007', '20141006'],
        ['', @existing_invoice.invoice_number.to_s]
      ]

      EntryPurge.create! broker_reference: "file1", source_system: "Alliance"

      expect(subject).not_to receive(:request_missing_data)
      subject.process_alliance_query_details results.to_json

      expect(OpenMailer.deliveries.length).to eq 0
    end

    it "doesn't send email if no files or invoices are missing" do
      results = [
        [@existing_entry.broker_reference, ''],
        ['', @existing_invoice.invoice_number.to_s]
      ]
      expect(subject).not_to receive(:request_missing_data)
      subject.process_alliance_query_details results.to_json

      expect(OpenMailer.deliveries.length).to eq 0
    end
  end

  describe "run_schedulable" do

    it "calculates start and end dates when run via schedule" do
      now = Time.zone.now
      # Start Date defaults to 7 days ago
      start_date = (now.in_time_zone("Eastern Time (US & Canada)") - 7.days).to_date
      end_time = (now - 1.hour)

      expect(OpenChain::KewillSqlProxyClient).to receive(:request_file_tracking_info).with start_date, end_time
      allow_any_instance_of(ActiveSupport::TimeZone).to receive(:now).and_return now

      subject.run_schedulable
    end

    it "uses days_ago param" do
      now = Time.zone.now
      start_date = (now.in_time_zone("Eastern Time (US & Canada)") - 2.days).to_date
      end_time = (now - 1.hour)

      expect(OpenChain::KewillSqlProxyClient).to receive(:request_file_tracking_info).with start_date, end_time
      allow_any_instance_of(ActiveSupport::TimeZone).to receive(:now).and_return now

      subject.run_schedulable({'days_ago' => '2'})
    end
  end
end