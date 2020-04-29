describe OpenChain::CustomHandler::UnderArmour::UnderArmour315Generator do

  describe "accepts?" do

    it "should accept a UA entry with invoice lines" do
      entry = Entry.new importer_tax_id: "874548506RM0001"
      entry.commercial_invoice_lines.build

      expect(described_class.new.accepts?(nil, entry)).to be_truthy
    end

    it "should not accept a UA entry without invoice lines" do
      entry = Entry.new importer_tax_id: "874548506RM0001"
      expect(described_class.new.accepts?(nil, entry)).to be_falsey
    end

    it "should not accept non-UA entry" do
      entry = Entry.new customer_number: "NOT UNDERARMOUR'S TAX ID"
      entry.commercial_invoice_lines.build

      expect(described_class.new.accepts?(nil, entry)).to be_falsey
    end
  end

  describe "receive" do
    let (:entry) { Factory(:entry, cadex_sent_date: Time.zone.now, release_date: Time.zone.now + 1.day, first_do_issued_date: Time.zone.now + 2.days) }
    let (:invoice) { Factory(:commercial_invoice, entry: entry) }
    let! (:inv_line_1) { Factory(:commercial_invoice_line, customer_reference: "ABC", commercial_invoice: invoice) }
    let! (:inv_line_2) { Factory(:commercial_invoice_line, customer_reference: "ABC", commercial_invoice: invoice) }
    let! (:inv_line_3) { Factory(:commercial_invoice_line, customer_reference: "DEF", commercial_invoice: invoice) }

    before :each do
      allow(subject).to receive(:delay).and_return subject
    end

    def xml_date date
      date.in_time_zone("GMT").iso8601[0..-7]
    end

    it "should trigger one xml file per shipment id / event code combination" do
      expect(subject).to receive(:generate_and_send).with(event_code: '2315', shipment_identifier: 'ABC', date: entry.cadex_sent_date)
      expect(subject).to receive(:generate_and_send).with(event_code: '2326', shipment_identifier: 'ABC', date: entry.release_date)
      expect(subject).to receive(:generate_and_send).with(event_code: '2902', shipment_identifier: 'ABC', date: entry.first_do_issued_date)

      expect(subject).to receive(:generate_and_send).with(event_code: '2315', shipment_identifier: 'DEF', date: entry.cadex_sent_date)
      expect(subject).to receive(:generate_and_send).with(event_code: '2326', shipment_identifier: 'DEF', date: entry.release_date)
      expect(subject).to receive(:generate_and_send).with(event_code: '2902', shipment_identifier: 'DEF', date: entry.first_do_issued_date)

      subject.receive nil, entry

      # Make sure the correct cross reference values were created.
      expect(DataCrossReference.find_ua_315_milestone("ABC", "2315")).to eq xml_date(entry.cadex_sent_date)
      expect(DataCrossReference.find_ua_315_milestone("ABC", "2326")).to eq xml_date(entry.release_date)
      expect(DataCrossReference.find_ua_315_milestone("ABC", "2902")).to eq xml_date(entry.first_do_issued_date)

      expect(DataCrossReference.find_ua_315_milestone("DEF", "2315")).to eq xml_date(entry.cadex_sent_date)
      expect(DataCrossReference.find_ua_315_milestone("DEF", "2326")).to eq xml_date(entry.release_date)
      expect(DataCrossReference.find_ua_315_milestone("DEF", "2902")).to eq xml_date(entry.first_do_issued_date)
    end

    it "should handle reformatting the shipment id" do
      inv_line_1.update_attributes! customer_reference: "ABC-123"
      inv_line_2.update_attributes! customer_reference: "ABC-123"
      inv_line_3.update_attributes! customer_reference: "ABC-123"

      expect(subject).to receive(:generate_and_send).with(event_code: '2315', shipment_identifier: 'ABC', date: entry.cadex_sent_date)
      expect(subject).to receive(:generate_and_send).with(event_code: '2326', shipment_identifier: 'ABC', date: entry.release_date)
      expect(subject).to receive(:generate_and_send).with(event_code: '2902', shipment_identifier: 'ABC', date: entry.first_do_issued_date)

      subject.receive nil, entry

      expect(DataCrossReference.find_ua_315_milestone("ABC", "2315")).to eq xml_date(entry.cadex_sent_date)
      expect(DataCrossReference.find_ua_315_milestone("ABC", "2326")).to eq xml_date(entry.release_date)
      expect(DataCrossReference.find_ua_315_milestone("ABC", "2902")).to eq xml_date(entry.first_do_issued_date)
    end

    it "should not trigger xml for date values that have already been sent" do
      inv_line_3.destroy

      DataCrossReference.add_xref! DataCrossReference::UA_315_MILESTONE_EVENT, DataCrossReference.make_compound_key("ABC", "2315"), xml_date(entry.cadex_sent_date)
      DataCrossReference.add_xref! DataCrossReference::UA_315_MILESTONE_EVENT, DataCrossReference.make_compound_key("ABC", "2326"), xml_date(entry.release_date)
      DataCrossReference.add_xref! DataCrossReference::UA_315_MILESTONE_EVENT, DataCrossReference.make_compound_key("ABC", "2902"), xml_date(entry.first_do_issued_date)

      subject.receive nil, entry
      expect(subject).not_to receive(:generate_and_send)
    end

    it "should trigger xml for updated date values" do
      inv_line_3.destroy

      DataCrossReference.add_xref! DataCrossReference::UA_315_MILESTONE_EVENT, DataCrossReference.make_compound_key("ABC", "2315"), xml_date(entry.cadex_sent_date)
      DataCrossReference.add_xref! DataCrossReference::UA_315_MILESTONE_EVENT, DataCrossReference.make_compound_key("ABC", "2326"), xml_date(entry.release_date)
      DataCrossReference.add_xref! DataCrossReference::UA_315_MILESTONE_EVENT, DataCrossReference.make_compound_key("ABC", "2902"), xml_date(entry.first_do_issued_date)

      expect(subject).to receive(:generate_and_send).with(event_code: '2315', shipment_identifier: 'ABC', date: entry.cadex_sent_date + 1.day)

      entry.cadex_sent_date = entry.cadex_sent_date + 1.day
      subject.receive nil, entry

      expect(DataCrossReference.find_ua_315_milestone("ABC", "2315")).to eq xml_date(entry.cadex_sent_date)
    end

    it "should not trigger xml for blank date values" do
      entry.update_attributes! cadex_sent_date: nil, release_date: nil, first_do_issued_date: nil
      subject.receive nil, entry
      expect(subject).not_to receive(:generate_and_send)
    end
  end

  describe "generate_and_send" do
    let (:entry_data) { {shipment_identifier: "IO", event_code: "EVENT_CODE", date: Time.zone.now} }

    before :each do
      @filename = nil
      allow(subject).to receive(:ftp_file) do |file, opts|
        expect(opts[:keep_local]).to be_truthy
        file.rewind
        @filename = file.original_filename
        @xml_data = REXML::Document.new(file.read)
      end
    end

    it "generates xml and ftp it" do
      now = Time.zone.now
      Timecop.freeze(now) {subject.generate_and_send entry_data }

      sha = Digest::SHA1.hexdigest("#{entry_data[:shipment_identifier]}#{entry_data[:event_code]}#{entry_data[:date]}")

      expect(REXML::XPath.first(@xml_data, "/tXML/Message/MANH_TPM_Shipment_IBD/@Id").value).to eq entry_data[:shipment_identifier]
      expect(REXML::XPath.first(@xml_data, "/tXML/Message/MANH_TPM_Shipment_IBD/Shipment/@Id").value).to eq entry_data[:shipment_identifier]
      expect(REXML::XPath.first(@xml_data, "/tXML/Message/MANH_TPM_Shipment_IBD/Shipment/IBDNumber").text).to eq nil
      expect(REXML::XPath.first(@xml_data, "/tXML/Message/MANH_TPM_Shipment_IBD/@DocSource").value).to eq "Vande"
      expect(REXML::XPath.first(@xml_data, "/tXML/Message/MANH_TPM_Shipment_IBD/Shipment/Event/EventLocation/@InternalId").value).to eq "VFICA"
      expect(REXML::XPath.first(@xml_data, "/tXML/Message/MANH_TPM_Shipment_IBD/Shipment/Event/@Id").value).to eq sha
      expect(REXML::XPath.first(@xml_data, "/tXML/Message/MANH_TPM_Shipment_IBD/Shipment/Event/@Code").value).to eq entry_data[:event_code]
      expect(REXML::XPath.first(@xml_data, "/tXML/Message/MANH_TPM_Shipment_IBD/Shipment/Event/@DateTime").value).to eq entry_data[:date].in_time_zone("GMT").iso8601[0..-7]

      expect(@filename).to eq "LSPEVT_IO_EVENT_CODE_#{now.strftime "%Y%m%d%H%M%S%L"}.xml"
    end

    it "pulls IBD number from shipment data" do
      Factory(:shipment, reference: "UNDAR-#{entry_data[:shipment_identifier]}", booking_number: "IBDNUMBER")

      subject.generate_and_send entry_data
      expect(REXML::XPath.first(@xml_data, "/tXML/Message/MANH_TPM_Shipment_IBD/@Id").value).to eq entry_data[:shipment_identifier]
      expect(REXML::XPath.first(@xml_data, "/tXML/Message/MANH_TPM_Shipment_IBD/Shipment/IBDNumber").text).to eq "IBDNUMBER"
    end
  end

  describe "generate_file" do
    it "should generate data to a file and return the file" do
      # make sure we're sanitizing the filename (add illegal characters for windows to make sure they're removed)
      entry_data = {shipment_identifier: "IO*?", event_code: "EVENT_CODE", date: Time.zone.now}
      g = described_class.new

      f = g.generate_file entry_data
      doc = REXML::Document.new(IO.read(f.path))

      expect(f.path.match(/\*/)).to be_nil
      expect(f.path.match(/\?/)).to be_nil

      # just verify some piece of data is there..the whole file is already validated in another test
      expect(REXML::XPath.first(doc, "/tXML/Message/MANH_TPM_Shipment_IBD/@Id").value).to eq entry_data[:shipment_identifier]
    end
  end

end