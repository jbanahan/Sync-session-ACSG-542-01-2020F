require 'rexml/document'

describe OpenChain::CustomHandler::LumberLiquidators::LumberAllportBillingFileParser do

  let(:user) { Factory(:user, email:'fake@emailaddress.com') }

  describe 'can_view?' do
    let(:subject) { described_class.new(nil) }
    let(:ms) { stub_master_setup }

    it "allow master users on systems with feature" do
      expect(ms).to receive(:custom_feature?).with('Lumber ACS Billing Validation').and_return true
      expect(user.company).to receive(:broker?).and_return true
      expect(subject.can_view? user).to eq true
    end

    it "blocks non-master users on systems with feature" do
      allow(ms).to receive(:custom_feature?).with('Lumber ACS Billing Validation').and_return true
      expect(user.company).to receive(:broker?).and_return false
      expect(subject.can_view? user).to eq false
    end

    it "blocks master users on systems without feature" do
      expect(ms).to receive(:custom_feature?).with('Lumber ACS Billing Validation').and_return false
      expect(user.company).to receive(:broker?).and_return true
      expect(subject.can_view? user).to eq false
    end
  end

  describe 'valid_file?' do
    it "allows expected file extensions and forbids weird ones" do
      expect(described_class.valid_file? 'abc.CSV').to eq false
      expect(described_class.valid_file? 'abc.csv').to eq false
      expect(described_class.valid_file? 'def.XLS').to eq true
      expect(described_class.valid_file? 'def.xls').to eq true
      expect(described_class.valid_file? 'ghi.XLSX').to eq true
      expect(described_class.valid_file? 'ghi.xlsx').to eq true
      expect(described_class.valid_file? 'xls.txt').to eq false
      expect(described_class.valid_file? 'abc.').to eq false
    end
  end

  describe 'process' do
    let! (:master_setup) {
      ms = stub_master_setup
      allow(ms).to receive(:request_host).and_return 'some_host'
      ms
    }

    let(:custom_file) { double "custom file" }
    let(:attachment) { File.open('spec/fixtures/files/test_sheet_1.xls', 'rb') }
    let(:file_reader) { double "dummy reader" }
    let(:header_row) { ["A", "B", "C", "D", "E", "F", "G"] }
    let(:column_header_row) { ["Purchase Order", "BL/AWB/PRO", "Container", "Vessel", "POL", "Service Type", "CY/CY (FCL) Management Fee"] }
    let(:blank_row) { ["", "", "", "", "", "", ""] }
    let(:row_1) { ["x", "BOL-1", "CON-1", "x", "x", "x", "50.55"] }
    let(:row_1b) { ["x", "BOL-1", "CON-2", "x", "x", "x", "20.10"] }
    let(:row_2) { ["x", "BOL-2", "CON-3", "x", "x", "x", "25.25"] }
    let(:totals_row) { ["", "", "", "", "", "", "75.75"] }

    subject { described_class.new(custom_file) }

    before :each do 
      allow(custom_file).to receive(:attached_file_name).and_return "file.xls"
      allow(custom_file).to receive(:attached).and_return attachment
      allow(Attachment).to receive(:bucket).and_return "test-bucket"
      allow(attachment).to receive(:path).and_return attachment.path
      allow(OpenChain::S3).to receive(:download_to_tempfile).with("test-bucket", attachment.path, {original_filename: "file.xls"}).and_yield attachment
    end

    def yield_standard_header base
      base.and_yield(header_row).and_yield(header_row).and_yield(header_row).and_yield(header_row).and_yield(header_row).
          and_yield(header_row).and_yield(header_row).and_yield(blank_row).
          and_yield(header_row).and_yield(header_row).and_yield(header_row).and_yield(blank_row).and_yield(blank_row).
          and_yield(header_row).and_yield(blank_row).and_yield(column_header_row)
    end

    it "parses file and generates new spreadsheet based on it" do
      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      yield_standard_header(expect(file_reader).to receive(:foreach)).
          and_yield(row_1).and_yield(row_1b).and_yield(row_2).and_yield(blank_row).and_yield(totals_row)

      entry_1 = Factory(:entry,
          customer_number:'LUMBER',
          source_system:Entry::KEWILL_SOURCE_SYSTEM,
          customer_name:'Crudco',
          broker_reference:'BR12345',
          entry_number:'ENT12345',
          bol_received_date:ActiveSupport::TimeZone['UTC'].parse('2018-03-07 10:35:11'),
          export_date:ActiveSupport::TimeZone['UTC'].parse('2018-03-08 11:45:22'),
          entry_filed_date:ActiveSupport::TimeZone['UTC'].parse('2018-03-09 12:55:33'),
          release_date:ActiveSupport::TimeZone['UTC'].parse('2017-02-10 13:05:44'),
          master_bills_of_lading:"BOL-1\nBOL-X",
          house_bills_of_lading:"BOL-Y\nBOL-Z",
          container_numbers:"CON-1\nCON-2",
          container_sizes:"45ft\n25ft",
          broker_invoice_total:1234.56
      )
      container_1 = Factory(:container, container_number:'CON-1', entry:entry_1)
      container_2 = Factory(:container, container_number:'CON-2', entry:entry_1)
      invoice_1 = Factory(:broker_invoice, entry:entry_1)
      entry_1.save!

      entry_2 = Factory(:entry,
          customer_number:'LUMBER',
          source_system:Entry::KEWILL_SOURCE_SYSTEM,
          customer_name:'Stufftek',
          broker_reference:'BR67890',
          entry_number:'ENT67890',
          bol_received_date:ActiveSupport::TimeZone['UTC'].parse('2017-03-07 10:35:11'),
          export_date:ActiveSupport::TimeZone['UTC'].parse('2017-03-08 11:45:22'),
          entry_filed_date:ActiveSupport::TimeZone['UTC'].parse('2017-03-09 12:55:33'),
          release_date:ActiveSupport::TimeZone['UTC'].parse('2017-02-11 13:05:44'),
          master_bills_of_lading:'OTHER BOL',
          house_bills_of_lading:'BOL-2',
          container_numbers:'CON-3',
          container_sizes:'22ft',
          broker_invoice_total:789.01
      )
      container_3 = Factory(:container, container_number:'CON-3', entry:entry_2)
      invoice_2 = Factory(:broker_invoice, entry:entry_2)
      entry_2.save!

      now = ActiveSupport::TimeZone['UTC'].parse('2017-03-06 16:30:12')
      Timecop.freeze(now) do
        subject.process user
      end

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['fake@emailaddress.com']
      expect(mail.subject).to eq 'Lumber ACS Billing Validation Report'
      expect(mail.body).to include "The attached report was generated based on a report uploaded to VFI Track, which is also attached to this email."
      expect(mail.body).not_to include "Errors encountered"
      expect(mail.attachments.length).to eq(2)

      # The newly-generated spreadsheet is the first attachment.
      attachment_1 = mail.attachments[0]
      expect(attachment_1.filename).to eq("Lumber_ACS_billing_report_2017-03-06.xls")
      sheet = Spreadsheet.open(StringIO.new(attachment_1.read)).worksheets.first
      expect(sheet.rows.length).to eq 4
      expect(sheet.row(0)).to eq ["Customer Name", "Customer Number", "Broker Reference", "Entry Number", "BOL Date", "Export Date", "Entry Filed Date", "Release Date", "Master Bills", "House Bills", "Container Numbers", "Container Sizes", "Total Broker Invoice", "Container Count", "Cost", "Links"]

      expect(sheet.row(1)[0]).to eq 'Crudco'
      expect(sheet.row(1)[1]).to eq 'LUMBER'
      expect(sheet.row(1)[2]).to eq 'BR12345'
      expect(sheet.row(1)[3]).to eq 'ENT12345'
      expect(sheet.row(1)[4]).to eq ActiveSupport::TimeZone['UTC'].parse('2018-03-07 10:35:11')
      expect(sheet.row(1)[5]).to eq ActiveSupport::TimeZone['UTC'].parse('2018-03-08 11:45:22').to_date
      expect(sheet.row(1)[6]).to eq ActiveSupport::TimeZone['UTC'].parse('2018-03-09 12:55:33')
      expect(sheet.row(1)[7]).to eq ActiveSupport::TimeZone['UTC'].parse('2017-02-10 13:05:44')
      expect(sheet.row(1)[8]).to eq 'BOL-1,BOL-X'
      expect(sheet.row(1)[9]).to eq 'BOL-Y,BOL-Z'
      expect(sheet.row(1)[10]).to eq 'CON-1,CON-2'
      expect(sheet.row(1)[11]).to eq '45ft,25ft'
      expect(sheet.row(1)[12]).to eq 1234.56
      expect(sheet.row(1)[13]).to eq 2
      expect(sheet.row(1)[14]).to eq 70.65
      expect(sheet.row(1)[15]).to be_an_instance_of Spreadsheet::Link
      expect(sheet.row(1)[15].href).to include "entries/#{entry_1.id}"
      expect(sheet.row(1)[15].to_s).to eq "Web View"

      expect(sheet.row(2)[0]).to eq 'Stufftek'
      expect(sheet.row(2)[1]).to eq 'LUMBER'
      expect(sheet.row(2)[2]).to eq 'BR67890'
      expect(sheet.row(2)[3]).to eq 'ENT67890'
      expect(sheet.row(2)[4]).to eq ActiveSupport::TimeZone['UTC'].parse('2017-03-07 10:35:11')
      expect(sheet.row(2)[5]).to eq ActiveSupport::TimeZone['UTC'].parse('2017-03-08 11:45:22').to_date
      expect(sheet.row(2)[6]).to eq ActiveSupport::TimeZone['UTC'].parse('2017-03-09 12:55:33')
      expect(sheet.row(2)[7]).to eq ActiveSupport::TimeZone['UTC'].parse('2017-02-11 13:05:44')
      expect(sheet.row(2)[8]).to eq 'OTHER BOL'
      expect(sheet.row(2)[9]).to eq 'BOL-2'
      expect(sheet.row(2)[10]).to eq 'CON-3'
      expect(sheet.row(2)[11]).to eq '22ft'
      expect(sheet.row(2)[12]).to eq 789.01
      expect(sheet.row(2)[13]).to eq 1
      expect(sheet.row(2)[14]).to eq 25.25
      expect(sheet.row(2)[15]).to be_an_instance_of Spreadsheet::Link
      expect(sheet.row(2)[15].href).to include "entries/#{entry_2.id}"
      expect(sheet.row(2)[15].to_s).to eq "Web View"

      expect(sheet.row(3)[0]).to be_nil
      expect(sheet.row(3)[1]).to be_nil
      expect(sheet.row(3)[2]).to be_nil
      expect(sheet.row(3)[3]).to be_nil
      expect(sheet.row(3)[4]).to be_nil
      expect(sheet.row(3)[5]).to be_nil
      expect(sheet.row(3)[6]).to be_nil
      expect(sheet.row(3)[7]).to be_nil
      expect(sheet.row(3)[8]).to be_nil
      expect(sheet.row(3)[9]).to be_nil
      expect(sheet.row(3)[10]).to be_nil
      expect(sheet.row(3)[11]).to be_nil
      expect(sheet.row(3)[12]).to be_nil
      expect(sheet.row(3)[13]).to be_nil
      expect(sheet.row(3)[14]).to eq 95.90
      expect(sheet.row(3)[15]).to be_nil

      # The original spreadsheet is the second attachment.
      expect(mail.attachments[1].filename).to eq("test_sheet_1.xls")
    end

    it "handles lines that cannot be matched by BOL or container" do
      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      yield_standard_header(expect(file_reader).to receive(:foreach)).
          and_yield(row_1).and_yield(row_2).and_yield(row_1).and_yield(blank_row).and_yield(totals_row)

      entry_2 = Factory(:entry, master_bills_of_lading:'OTHER BOL', house_bills_of_lading:'BOL-2', customer_number:'LUMBER', source_system:Entry::KEWILL_SOURCE_SYSTEM, release_date:DateTime.now)
      invoice_2 = Factory(:broker_invoice, entry:entry_2)

      subject.process user

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['fake@emailaddress.com']
      expect(mail.subject).to eq 'Lumber ACS Billing Validation Report'
      expect(mail.body).to include "The attached report was generated based on a report uploaded to VFI Track, which is also attached to this email.<br><br>Errors encountered:<br>Row 17: There were no matching entries for bill of lading 'BOL-1' or container 'CON-1'.<br>Row 19: There were no matching entries for bill of lading 'BOL-1' or container 'CON-1'."
      expect(mail.attachments.length).to eq(2)

      # The newly-generated spreadsheet will still contain data for the "good" line.
      attachment_1 = mail.attachments[0]
      sheet = Spreadsheet.open(StringIO.new(attachment_1.read)).worksheets.first
      expect(sheet.rows.length).to eq 3
      expect(sheet.row(0)).to eq ["Customer Name", "Customer Number", "Broker Reference", "Entry Number", "BOL Date", "Export Date", "Entry Filed Date", "Release Date", "Master Bills", "House Bills", "Container Numbers", "Container Sizes", "Total Broker Invoice", "Container Count", "Cost", "Links"]

      expect(sheet.row(1)[8]).to eq 'OTHER BOL'
      expect(sheet.row(1)[9]).to eq 'BOL-2'
      expect(sheet.row(1)[14]).to eq 25.25
      expect(sheet.row(1)[15].href).to include "entries/#{entry_2.id}"

      expect(sheet.row(2)[14]).to eq 25.25

      # The original spreadsheet is the second attachment.
      expect(mail.attachments[1].filename).to eq("test_sheet_1.xls")
    end

    it "handles line that has multiple BOL matches but only one container number match" do
      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      yield_standard_header(expect(file_reader).to receive(:foreach)).
          and_yield(row_1)

      entry_1 = Factory(:entry, master_bills_of_lading:'BOL-1', container_numbers:'CON-1,CON-2', customer_number:'LUMBER', source_system:Entry::KEWILL_SOURCE_SYSTEM, release_date:DateTime.now)
      invoice_1 = Factory(:broker_invoice, entry:entry_1)
      entry_2 = Factory(:entry, master_bills_of_lading:'BOL-1', container_numbers:'CON-3', customer_number:'LUMBER', source_system:Entry::KEWILL_SOURCE_SYSTEM, release_date:DateTime.now)

      subject.process user

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['fake@emailaddress.com']
      expect(mail.subject).to eq 'Lumber ACS Billing Validation Report'
      expect(mail.body).not_to include "Errors encountered"
      expect(mail.attachments.length).to eq(2)

      attachment_1 = mail.attachments[0]
      sheet = Spreadsheet.open(StringIO.new(attachment_1.read)).worksheets.first
      expect(sheet.rows.length).to eq 3
      expect(sheet.row(1)[8]).to eq 'BOL-1'
      expect(sheet.row(1)[10]).to eq 'CON-1,CON-2'
      expect(sheet.row(1)[15].href).to include "entries/#{entry_1.id}"
    end

    it "handles line that has multiple BOL and container number matches" do
      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      yield_standard_header(expect(file_reader).to receive(:foreach)).
          and_yield(row_1)

      entry_1 = Factory(:entry, broker_reference:'BR12345', master_bills_of_lading:'BOL-1', container_numbers:'CON-1,CON-2', customer_number:'LUMBER', source_system:Entry::KEWILL_SOURCE_SYSTEM, release_date:DateTime.now)
      invoice_1 = Factory(:broker_invoice, entry:entry_1)
      entry_2 = Factory(:entry, broker_reference:'BR67890', master_bills_of_lading:'BOL-1', container_numbers:'CON-3,CON-1', customer_number:'LUMBER', source_system:Entry::KEWILL_SOURCE_SYSTEM, release_date:DateTime.now)
      invoice_2 = Factory(:broker_invoice, entry:entry_2)

      subject.process user

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['fake@emailaddress.com']
      expect(mail.subject).to eq 'Lumber ACS Billing Validation Report'
      expect(mail.body).to include "The attached report was generated based on a report uploaded to VFI Track, which is also attached to this email.<br><br>Errors encountered:<br>Row 17: Multiple entry matches found for bill of lading 'BOL-1': BR12345, BR67890."
      expect(mail.attachments.length).to eq(2)

      attachment_1 = mail.attachments[0]
      sheet = Spreadsheet.open(StringIO.new(attachment_1.read)).worksheets.first
      expect(sheet.rows.length).to eq 1
      expect(sheet.row(0)).to eq ["Customer Name", "Customer Number", "Broker Reference", "Entry Number", "BOL Date", "Export Date", "Entry Filed Date", "Release Date", "Master Bills", "House Bills", "Container Numbers", "Container Sizes", "Total Broker Invoice", "Container Count", "Cost", "Links"]
    end

    it "handles line that matches multiple entries by container number" do
      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      yield_standard_header(expect(file_reader).to receive(:foreach)).
          and_yield(row_1)

      entry_1 = Factory(:entry, broker_reference:'BR12345', container_numbers:'CON-1,CON-2', customer_number:'LUMBER', source_system:Entry::KEWILL_SOURCE_SYSTEM, release_date:DateTime.now)
      entry_2 = Factory(:entry, broker_reference:'BR67890', container_numbers:'CON-3,CON-1', customer_number:'LUMBER', source_system:Entry::KEWILL_SOURCE_SYSTEM, release_date:DateTime.now)

      subject.process user

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['fake@emailaddress.com']
      expect(mail.subject).to eq 'Lumber ACS Billing Validation Report'
      expect(mail.body).to include "The attached report was generated based on a report uploaded to VFI Track, which is also attached to this email.<br><br>Errors encountered:<br>Row 17: Multiple entry matches found for container 'CON-1': BR12345, BR67890."
      expect(mail.attachments.length).to eq(2)

      attachment_1 = mail.attachments[0]
      sheet = Spreadsheet.open(StringIO.new(attachment_1.read)).worksheets.first
      expect(sheet.rows.length).to eq 1
      expect(sheet.row(0)).to eq ["Customer Name", "Customer Number", "Broker Reference", "Entry Number", "BOL Date", "Export Date", "Entry Filed Date", "Release Date", "Master Bills", "House Bills", "Container Numbers", "Container Sizes", "Total Broker Invoice", "Container Count", "Cost", "Links"]
    end

    it "handles line that matches a skeletal entry by master bill" do
      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      yield_standard_header(expect(file_reader).to receive(:foreach)).
          and_yield(row_1)

      entry = Factory(:entry, broker_reference:'BR12345', master_bills_of_lading:'BOL-1', container_numbers:'CON-1,CON-2', customer_number:'LUMBER', source_system:Entry::KEWILL_SOURCE_SYSTEM, release_date:DateTime.now)
      # No broker invoices.

      subject.process user

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['fake@emailaddress.com']
      expect(mail.subject).to eq 'Lumber ACS Billing Validation Report'
      expect(mail.body).to include "The attached report was generated based on a report uploaded to VFI Track, which is also attached to this email.<br><br>Errors encountered:<br>Row 17: The only entry with bill of lading 'BOL-1' has not been billed and cannot be used for matching purposes: BR12345."
      expect(mail.attachments.length).to eq(2)

      attachment_1 = mail.attachments[0]
      sheet = Spreadsheet.open(StringIO.new(attachment_1.read)).worksheets.first
      expect(sheet.rows.length).to eq 1
      expect(sheet.row(0)).to eq ["Customer Name", "Customer Number", "Broker Reference", "Entry Number", "BOL Date", "Export Date", "Entry Filed Date", "Release Date", "Master Bills", "House Bills", "Container Numbers", "Container Sizes", "Total Broker Invoice", "Container Count", "Cost", "Links"]
    end

    it "handles line that successfully matches on container number" do
      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      yield_standard_header(expect(file_reader).to receive(:foreach)).
          and_yield(row_1)

      entry_1 = Factory(:entry, broker_reference:'BR12345', container_numbers:'CON-1,CON-2', customer_number:'LUMBER', source_system:Entry::KEWILL_SOURCE_SYSTEM, release_date:DateTime.now)

      subject.process user

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['fake@emailaddress.com']
      expect(mail.subject).to eq 'Lumber ACS Billing Validation Report'
      expect(mail.body).not_to include "Errors encountered"
      expect(mail.attachments.length).to eq(2)

      attachment_1 = mail.attachments[0]
      sheet = Spreadsheet.open(StringIO.new(attachment_1.read)).worksheets.first
      expect(sheet.rows.length).to eq 3
      expect(sheet.row(1)[10]).to eq 'CON-1,CON-2'
      expect(sheet.row(1)[15].href).to include "entries/#{entry_1.id}"
    end

    # This should be viewed as a mismatch, despite the BOL match.
    it "handles line that matches a non-Lumber entry by BOL" do
      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      yield_standard_header(expect(file_reader).to receive(:foreach)).
          and_yield(row_1)

      entry = Factory(:entry, broker_reference:'BR12345', master_bills_of_lading:'BOL-1', container_numbers:'CON-1', customer_number:'*NOT* LUMBER', source_system:Entry::KEWILL_SOURCE_SYSTEM, release_date:DateTime.now)
      invoice = Factory(:broker_invoice, entry:entry)

      subject.process user

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['fake@emailaddress.com']
      expect(mail.subject).to eq 'Lumber ACS Billing Validation Report'
      expect(mail.body).to include "The attached report was generated based on a report uploaded to VFI Track, which is also attached to this email.<br><br>Errors encountered:<br>Row 17: There were no matching entries for bill of lading 'BOL-1' or container 'CON-1'."
      expect(mail.attachments.length).to eq(2)

      attachment_1 = mail.attachments[0]
      sheet = Spreadsheet.open(StringIO.new(attachment_1.read)).worksheets.first
      expect(sheet.rows.length).to eq 1
      expect(sheet.row(0)).to eq ["Customer Name", "Customer Number", "Broker Reference", "Entry Number", "BOL Date", "Export Date", "Entry Filed Date", "Release Date", "Master Bills", "House Bills", "Container Numbers", "Container Sizes", "Total Broker Invoice", "Container Count", "Cost", "Links"]
    end

    # This should be viewed as a mismatch, despite the container match.
    it "handles line that matches a non-Lumber entry by container" do
      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      yield_standard_header(expect(file_reader).to receive(:foreach)).
          and_yield(row_1)

      entry = Factory(:entry, broker_reference:'BR12345', master_bills_of_lading:'BOL-X', container_numbers:'CON-1', customer_number:'*NOT* LUMBER', source_system:Entry::KEWILL_SOURCE_SYSTEM, release_date:DateTime.now)
      invoice = Factory(:broker_invoice, entry:entry)

      subject.process user

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['fake@emailaddress.com']
      expect(mail.subject).to eq 'Lumber ACS Billing Validation Report'
      expect(mail.body).to include "The attached report was generated based on a report uploaded to VFI Track, which is also attached to this email.<br><br>Errors encountered:<br>Row 17: There were no matching entries for bill of lading 'BOL-1' or container 'CON-1'."
      expect(mail.attachments.length).to eq(2)

      attachment_1 = mail.attachments[0]
      sheet = Spreadsheet.open(StringIO.new(attachment_1.read)).worksheets.first
      expect(sheet.rows.length).to eq 1
      expect(sheet.row(0)).to eq ["Customer Name", "Customer Number", "Broker Reference", "Entry Number", "BOL Date", "Export Date", "Entry Filed Date", "Release Date", "Master Bills", "House Bills", "Container Numbers", "Container Sizes", "Total Broker Invoice", "Container Count", "Cost", "Links"]
    end

    # This should be viewed as a mismatch, despite the BOL match.
    it "handles line that matches a non-Kewill entry by BOL" do
      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      yield_standard_header(expect(file_reader).to receive(:foreach)).
          and_yield(row_1)

      entry = Factory(:entry, broker_reference:'BR12345', master_bills_of_lading:'BOL-1', container_numbers:'CON-1', customer_number:'LUMBER', source_system:Entry::FENIX_SOURCE_SYSTEM, release_date:DateTime.now)
      invoice = Factory(:broker_invoice, entry:entry)

      subject.process user

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['fake@emailaddress.com']
      expect(mail.subject).to eq 'Lumber ACS Billing Validation Report'
      expect(mail.body).to include "The attached report was generated based on a report uploaded to VFI Track, which is also attached to this email.<br><br>Errors encountered:<br>Row 17: There were no matching entries for bill of lading 'BOL-1' or container 'CON-1'."
      expect(mail.attachments.length).to eq(2)

      attachment_1 = mail.attachments[0]
      sheet = Spreadsheet.open(StringIO.new(attachment_1.read)).worksheets.first
      expect(sheet.rows.length).to eq 1
      expect(sheet.row(0)).to eq ["Customer Name", "Customer Number", "Broker Reference", "Entry Number", "BOL Date", "Export Date", "Entry Filed Date", "Release Date", "Master Bills", "House Bills", "Container Numbers", "Container Sizes", "Total Broker Invoice", "Container Count", "Cost", "Links"]
    end

    # This should be viewed as a mismatch, despite the container match.
    it "handles line that matches a non-Kewill entry by container" do
      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      yield_standard_header(expect(file_reader).to receive(:foreach)).
          and_yield(row_1)

      entry = Factory(:entry, broker_reference:'BR12345', master_bills_of_lading:'BOL-X', container_numbers:'CON-1', customer_number:'LUMBER', source_system:Entry::FENIX_SOURCE_SYSTEM, release_date:DateTime.now)
      invoice = Factory(:broker_invoice, entry:entry)

      subject.process user

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['fake@emailaddress.com']
      expect(mail.subject).to eq 'Lumber ACS Billing Validation Report'
      expect(mail.body).to include "The attached report was generated based on a report uploaded to VFI Track, which is also attached to this email.<br><br>Errors encountered:<br>Row 17: There were no matching entries for bill of lading 'BOL-1' or container 'CON-1'."
      expect(mail.attachments.length).to eq(2)

      attachment_1 = mail.attachments[0]
      sheet = Spreadsheet.open(StringIO.new(attachment_1.read)).worksheets.first
      expect(sheet.rows.length).to eq 1
      expect(sheet.row(0)).to eq ["Customer Name", "Customer Number", "Broker Reference", "Entry Number", "BOL Date", "Export Date", "Entry Filed Date", "Release Date", "Master Bills", "House Bills", "Container Numbers", "Container Sizes", "Total Broker Invoice", "Container Count", "Cost", "Links"]
    end

    # This should be viewed as a mismatch, despite the BOL match.
    it "handles line that matches an entry by BOL, but it was released too long ago" do
      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      yield_standard_header(expect(file_reader).to receive(:foreach)).
          and_yield(row_1)

      entry = Factory(:entry, broker_reference:'BR12345', master_bills_of_lading:'BOL-1', container_numbers:'CON-1', customer_number:'LUMBER', source_system:Entry::KEWILL_SOURCE_SYSTEM, release_date:DateTime.new(2016,9,4))
      invoice = Factory(:broker_invoice, entry:entry)

      Timecop.freeze(DateTime.new(2017,3,6)) do
        subject.process user
      end

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['fake@emailaddress.com']
      expect(mail.subject).to eq 'Lumber ACS Billing Validation Report'
      expect(mail.body).to include "The attached report was generated based on a report uploaded to VFI Track, which is also attached to this email.<br><br>Errors encountered:<br>Row 17: There were no matching entries for bill of lading 'BOL-1' or container 'CON-1'."
      expect(mail.attachments.length).to eq(2)

      attachment_1 = mail.attachments[0]
      sheet = Spreadsheet.open(StringIO.new(attachment_1.read)).worksheets.first
      expect(sheet.rows.length).to eq 1
      expect(sheet.row(0)).to eq ["Customer Name", "Customer Number", "Broker Reference", "Entry Number", "BOL Date", "Export Date", "Entry Filed Date", "Release Date", "Master Bills", "House Bills", "Container Numbers", "Container Sizes", "Total Broker Invoice", "Container Count", "Cost", "Links"]
    end

    # This should be viewed as a mismatch, despite the container match.
    it "handles line that matches an entry by container, but it was released too long ago" do
      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      yield_standard_header(expect(file_reader).to receive(:foreach)).
          and_yield(row_1)

      entry = Factory(:entry, broker_reference:'BR12345', master_bills_of_lading:'BOL-X', container_numbers:'CON-1', customer_number:'LUMBER', source_system:Entry::KEWILL_SOURCE_SYSTEM, release_date:DateTime.new(2016,9,4))
      invoice = Factory(:broker_invoice, entry:entry)

      Timecop.freeze(DateTime.new(2017,3,6)) do
        subject.process user
      end

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['fake@emailaddress.com']
      expect(mail.subject).to eq 'Lumber ACS Billing Validation Report'
      expect(mail.body).to include "The attached report was generated based on a report uploaded to VFI Track, which is also attached to this email.<br><br>Errors encountered:<br>Row 17: There were no matching entries for bill of lading 'BOL-1' or container 'CON-1'."
      expect(mail.attachments.length).to eq(2)

      attachment_1 = mail.attachments[0]
      sheet = Spreadsheet.open(StringIO.new(attachment_1.read)).worksheets.first
      expect(sheet.rows.length).to eq 1
      expect(sheet.row(0)).to eq ["Customer Name", "Customer Number", "Broker Reference", "Entry Number", "BOL Date", "Export Date", "Entry Filed Date", "Release Date", "Master Bills", "House Bills", "Container Numbers", "Container Sizes", "Total Broker Invoice", "Container Count", "Cost", "Links"]
    end

    it "handles unexpected exception" do
      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      yield_standard_header(expect(file_reader).to receive(:foreach)).
          and_yield(row_1)

      entry = Factory(:entry, broker_reference:'BOL-1', container_numbers:'CON-1,CON-2', customer_number:'LUMBER', source_system:Entry::KEWILL_SOURCE_SYSTEM, release_date:DateTime.now)

      allow(XlsMaker).to receive(:add_body_row).and_raise(StandardError.new("This is a terrible error."))

      subject.process user

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['fake@emailaddress.com']
      expect(mail.subject).to eq 'Lumber ACS Billing Validation Report'
      expect(mail.body).to include "The attached report was generated based on a report uploaded to VFI Track, which is also attached to this email.<br><br>Errors encountered:<br>Row 17: Failed to process line due to the following error: 'This is a terrible error.'"
      expect(mail.attachments.length).to eq(2)

      attachment_1 = mail.attachments[0]
      sheet = Spreadsheet.open(StringIO.new(attachment_1.read)).worksheets.first
      expect(sheet.rows.length).to eq 1
      expect(sheet.row(0)).to eq ["Customer Name", "Customer Number", "Broker Reference", "Entry Number", "BOL Date", "Export Date", "Entry Filed Date", "Release Date", "Master Bills", "House Bills", "Container Numbers", "Container Sizes", "Total Broker Invoice", "Container Count", "Cost", "Links"]
    end

    it "handles abnormal length header" do
      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      expect(file_reader).to receive(:foreach).and_yield(header_row).and_yield(header_row).and_yield(header_row).
          and_yield(blank_row).and_yield(header_row).and_yield(column_header_row).and_yield(row_1)

      entry_1 = Factory(:entry, master_bills_of_lading:'BOL-1', container_numbers:'CON-1,CON-2', customer_number:'LUMBER', source_system:Entry::KEWILL_SOURCE_SYSTEM, release_date:DateTime.now)
      invoice_1 = Factory(:broker_invoice, entry:entry_1)

      subject.process user

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['fake@emailaddress.com']
      expect(mail.subject).to eq 'Lumber ACS Billing Validation Report'
      expect(mail.body).not_to include "Errors encountered"
      expect(mail.attachments.length).to eq(2)

      attachment_1 = mail.attachments[0]
      sheet = Spreadsheet.open(StringIO.new(attachment_1.read)).worksheets.first
      expect(sheet.rows.length).to eq 3
      expect(sheet.row(1)[8]).to eq 'BOL-1'
      expect(sheet.row(1)[15].href).to include "entries/#{entry_1.id}"
    end

    it "sends error email if column headings line malformed" do
      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      # Somebody changed the text of the first two columns, the two values that the parser uses to try to find where the data starts.
      bad_column_header_row = ["PO", "BOL", "Container", "Vessel", "POL", "Service Type", "CY/CY (FCL) Management Fee"]
      expect(file_reader).to receive(:foreach).and_yield(header_row).and_yield(header_row).and_yield(header_row).
          and_yield(blank_row).and_yield(header_row).and_yield(bad_column_header_row).and_yield(row_1)

      entry_1 = Factory(:entry, master_bills_of_lading:'BOL-1', container_numbers:'CON-1,CON-2', customer_number:'LUMBER', source_system:Entry::KEWILL_SOURCE_SYSTEM, release_date:DateTime.now)
      invoice_1 = Factory(:broker_invoice, entry:entry_1)

      subject.process user

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['fake@emailaddress.com']
      expect(mail.subject).to eq 'Malformed Lumber ACS Billing File'
      expect(mail.body).to include "This file could not be processed because the column header line could not be found.  In order for that line to be found, the first two column headings must be (exactly) 'Purchase Order' and 'BL/AWB/PRO'.  Please correct and upload the file again.".html_safe
      expect(mail.body).not_to include "The attached report was generated based on a report uploaded to VFI Track, which is also attached to this email."
      expect(mail.attachments.length).to eq(1)

      # The original spreadsheet is the only attachment.
      expect(mail.attachments[0].filename).to eq("test_sheet_1.xls")
    end
  end

end