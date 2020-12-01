describe OpenChain::CustomHandler::Pvh::PvhBillingFileGeneratorSupport do
  subject {
    Class.new do
      include OpenChain::CustomHandler::Pvh::PvhBillingFileGeneratorSupport

      def duty_invoice_number p1, p2
        raise "Mock this."
      end
    end.new
  }


  let! (:pvh) {
    FactoryBot(:importer, system_code: "PVH")
  }

  let (:us) { FactoryBot(:country, iso_code: "US") }

  let (:entry) {
    e = FactoryBot(:entry, entry_number: "ENTRYNUM", broker_reference: "12345", importer_id: pvh.id, transport_mode_code: "10", customer_number: "PVH", container_numbers: "ABCD1234567890", master_bills_of_lading: "MBOL9999\n MBOL1234567890", import_country: us, one_usg_date: Date.new(2018, 11, 6))
    i = e.commercial_invoices.create! invoice_number: "INV"
    i.commercial_invoice_lines.create! po_number: "PO", part_number: "PART", quantity: 1, unit_price: 1

    e
  }

  let (:broker_invoice_1) {
    i = FactoryBot(:broker_invoice, entry: entry, customer_number: "PVH", invoice_total: BigDecimal("200"), invoice_date: Date.new(2018, 11, 7), bill_to_name: "PVH CORP")
    l = FactoryBot(:broker_invoice_line, broker_invoice: i, charge_amount: BigDecimal("200"), charge_code: "0100", charge_description: "CHARGE")
    i
  }

  let (:broker_invoice_2) {
    FactoryBot(:broker_invoice, entry: entry, customer_number: "PVH", bill_to_name: "PVH CORP")
  }

  let (:entry_snapshot) {
    entry.reload
    JSON.parse(CoreModule.find_by_object(entry).entity_json(entry))
  }


  describe 'generate_and_send' do
    before :each do
      broker_invoice_1
      broker_invoice_2
    end

    it "calls generate and send for all broker invoices in the snapshot" do
      expect(subject).to receive(:generate_and_send_invoice_files).with(entry_snapshot, instance_of(Hash), broker_invoice_1)
      expect(subject).to receive(:generate_and_send_invoice_files).with(entry_snapshot, instance_of(Hash), broker_invoice_2)

      subject.generate_and_send(entry_snapshot)
    end

    it "skips any invoices that have sync records indicating they were sent" do
      broker_invoice_1.sync_records.create! trading_partner: "PVH BILLING", sent_at: Time.zone.now

      expect(subject).to receive(:generate_and_send_invoice_files).with(entry_snapshot, instance_of(Hash), broker_invoice_2)

      subject.generate_and_send(entry_snapshot)
    end

    it "doesn't send anything if there are failed business rules" do
      expect(subject).not_to receive(:generate_and_send_invoice_files)
      expect(subject).to receive(:mf).with(entry_snapshot, "ent_failed_business_rules").and_return "failed rule"

      subject.generate_and_send(entry_snapshot)
    end

    it "doesn't send anything if there are no broker_invoices" do
      entry.broker_invoices.destroy_all
      expect(subject).not_to receive(:generate_and_send_invoice_files)

      subject.generate_and_send(entry_snapshot)
    end

    it "doesn't send anything there are no master bills" do
      entry.update! master_bills_of_lading: nil
      expect(subject).not_to receive(:generate_and_send_invoice_files)

      subject.generate_and_send(entry_snapshot)
    end

    it "doesn't send anything if there are no containers on Ocean entries" do
      entry.update! container_numbers: nil
      expect(subject).not_to receive(:generate_and_send_invoice_files)

      subject.generate_and_send(entry_snapshot)
    end

    it "does send if there are no containers on non-Ocean entries" do
      entry.update! container_numbers: nil, transport_mode_code: "40"
      expect(subject).to receive(:generate_and_send_invoice_files).exactly(2).times

      subject.generate_and_send(entry_snapshot)
    end

    it "doesn't send anything if there is no One USG date for US entries" do
      entry.update! one_usg_date: nil
      expect(subject).not_to receive(:generate_and_send_invoice_files)

      subject.generate_and_send(entry_snapshot)
    end

    it "sends for Canada if One USG is not present" do
      entry.update! one_usg_date: nil, import_country: FactoryBot(:country, iso_code: "CA")
      expect(subject).to receive(:generate_and_send_invoice_files).exactly(2).times

      subject.generate_and_send(entry_snapshot)
    end

    it "doesn't send anything if invoice lines are missing PO numbers" do
      entry.commercial_invoice_lines.update_all po_number: nil
      expect(subject).not_to receive(:generate_and_send_invoice_files)

      subject.generate_and_send(entry_snapshot)
    end

    it "doesn't send anything if invoice lines are missing part numbers" do
      entry.commercial_invoice_lines.update_all part_number: nil
      expect(subject).not_to receive(:generate_and_send_invoice_files)

      subject.generate_and_send(entry_snapshot)
    end

    it "doesn't send anything if invoice lines are missing unit price" do
      entry.commercial_invoice_lines.update_all unit_price: nil
      expect(subject).not_to receive(:generate_and_send_invoice_files)

      subject.generate_and_send(entry_snapshot)
    end

    it "doesn't send anything if invoice lines are missing units" do
      entry.commercial_invoice_lines.update_all quantity: nil
      expect(subject).not_to receive(:generate_and_send_invoice_files)

      subject.generate_and_send(entry_snapshot)
    end

    it "doesn't send anything if there are no invoice lines" do
      entry.commercial_invoices.destroy_all
      expect(subject).not_to receive(:generate_and_send_invoice_files)

      subject.generate_and_send(entry_snapshot)
    end

    it "skips US invoices that are not billed to PVH Corp" do
      broker_invoice_2.update! bill_to_name: "PVH Non-Corp"
      expect(subject).to receive(:generate_and_send_invoice_files).with(entry_snapshot, instance_of(Hash), broker_invoice_1)
      subject.generate_and_send(entry_snapshot)
    end

    it "skips US invoices that are not billed to PVH customer number" do
      broker_invoice_2.update! customer_number: "PVHNE"
      expect(subject).to receive(:generate_and_send_invoice_files).with(entry_snapshot, instance_of(Hash), broker_invoice_1)
      subject.generate_and_send(entry_snapshot)
    end

    it "accepts all Canadian invoices" do
      ca = FactoryBot(:country, iso_code: "CA")
      entry.update! import_country: ca
      broker_invoice_2.update! bill_to_name: "PVH Non-Corp"

      expect(subject).to receive(:generate_and_send_invoice_files).with(entry_snapshot, instance_of(Hash), broker_invoice_1)
      expect(subject).to receive(:generate_and_send_invoice_files).with(entry_snapshot, instance_of(Hash), broker_invoice_2)

      subject.generate_and_send(entry_snapshot)
    end
  end

  describe "generate_and_send_invoice_files" do
    before :each do
      broker_invoice_1
    end

    it "generates invoice files for all types", :without_partial_double_verification do
      invoice_snapshot = subject.json_child_entities(entry_snapshot, "BrokerInvoice").first
      expect(subject).to receive(:has_duty_charges?).with(invoice_snapshot).and_return true
      expect(subject).to receive(:generate_and_send_duty_charges).with(entry_snapshot, invoice_snapshot, broker_invoice_1)

      expect(subject).to receive(:has_container_charges?).with(invoice_snapshot).and_return true
      expect(subject).to receive(:generate_and_send_container_charges).with(entry_snapshot, invoice_snapshot, broker_invoice_1)

      subject.generate_and_send_invoice_files(entry_snapshot, invoice_snapshot, broker_invoice_1)

      sr = broker_invoice_1.sync_records.find {|sr| sr.trading_partner == "PVH BILLING"}
      expect(sr).not_to be_nil
      expect(sr.sent_at).not_to be_nil
    end

    it "marks invoice synced, even if no files sent", :without_partial_double_verification do
      invoice_snapshot = subject.json_child_entities(entry_snapshot, "BrokerInvoice").first
      expect(subject).to receive(:has_duty_charges?).with(invoice_snapshot).and_return false
      expect(subject).not_to receive(:generate_and_send_duty_charges)

      expect(subject).to receive(:has_container_charges?).with(invoice_snapshot).and_return false
      expect(subject).not_to receive(:generate_and_send_container_charges)

      subject.generate_and_send_invoice_files(entry_snapshot, invoice_snapshot, broker_invoice_1)

      sr = broker_invoice_1.sync_records.find {|sr| sr.trading_partner == "PVH BILLING"}
      expect(sr).not_to be_nil
      expect(sr.sent_at).not_to be_nil
    end

    it "sends credit invoices", :without_partial_double_verification do
      invoice_snapshot = subject.json_child_entities(entry_snapshot, "BrokerInvoice").first
      expect(subject).to receive(:credit_invoice?).with(invoice_snapshot).exactly(2).times.and_return true

      expect(subject).to receive(:has_duty_charges?).with(invoice_snapshot).and_return true
      expect(subject).to receive(:generate_and_send_reversal).with(entry_snapshot, invoice_snapshot, broker_invoice_1, "DUTY").and_return true
      expect(subject).not_to receive(:generate_and_send_duty_charges)

      expect(subject).to receive(:has_container_charges?).with(invoice_snapshot).and_return true
      expect(subject).to receive(:generate_and_send_reversal).with(entry_snapshot, invoice_snapshot, broker_invoice_1, "CONTAINER").and_return true
      expect(subject).not_to receive(:generate_and_send_container_charges)

      subject.generate_and_send_invoice_files(entry_snapshot, invoice_snapshot, broker_invoice_1)

      sr = broker_invoice_1.sync_records.find {|sr| sr.trading_partner == "PVH BILLING"}
      expect(sr).not_to be_nil
      expect(sr.sent_at).not_to be_nil
    end
  end

  describe 'generate_and_send_reversal' do

    let (:existing_xml_path) { 'spec/fixtures/files/pvh_outbound_generic_invoice.xml' }
    let (:existing_xml_data) { IO.read existing_xml_path }

    let (:new_invoice) {
      i = FactoryBot(:broker_invoice, entry: entry, invoice_total: BigDecimal("-200"), invoice_date: Date.new(2018, 11, 7), currency: "USD")
      l = FactoryBot(:broker_invoice_line, broker_invoice: i, charge_amount: BigDecimal("-200"), charge_code: "0100", charge_description: "CHARGE")
      i
    }

    let (:original_sync_record) {
      ftp_session = FtpSession.create!
      attachment = ftp_session.create_attachment!

      broker_invoice_1.sync_records.create! trading_partner: "PVH BILLING DUTY", sent_at: Time.zone.now, ftp_session_id: ftp_session.id
    }

    let (:xml_tempfile) {
      temp = instance_double(Tempfile)
      expect(temp).to receive(:read).and_return existing_xml_data
      temp
    }

    let (:captured_xml) { [] }

    before :each do
      original_sync_record
      new_invoice

      allow(subject).to receive(:ftp_sync_file) do |temp, sync_record|
        captured_xml << temp.read
      end
    end

    it "sends xml with all charges reversed" do
      invoice_snapshot = subject.json_child_entities(entry_snapshot, "BrokerInvoice").last
      expect_any_instance_of(Attachment).to receive(:download_to_tempfile).and_yield xml_tempfile
      expect(subject).to receive(:duty_invoice_number).and_return "DUTYINV"

      expect(subject.generate_and_send_reversal entry_snapshot, invoice_snapshot, new_invoice, "DUTY").to eq true

      expect(captured_xml.length).to eq 1

      x = REXML::Document.new(captured_xml.first).root
      expect(x).to have_xpath_value("GenericInvoices/GenericInvoice/InvoiceHeader/InvoiceNumber", "DUTYINV")

      lines = REXML::XPath.each(x, "GenericInvoices/GenericInvoice/InvoiceDetails/InvoiceLineItem[ChargeField/Type/Code = 'E063']").to_a
      expect(lines.length).to eq 2

      expect(lines[0]).not_to be_nil
      expect(lines[0]).to have_xpath_value("ChargeField/Purpose", "Decrement")
      expect(lines[0]).to have_xpath_value("ChargeField/Value", "100.0")

      # The xml file has a mix of increment and decrement in it to test both paths.
      expect(lines[1]).not_to be_nil
      expect(lines[1]).to have_xpath_value("ChargeField/Purpose", "Increment")
      expect(lines[1]).to have_xpath_value("ChargeField/Value", "200.0")

      # Make sure a reversal sync record was added
      expect(broker_invoice_1.sync_records.find {|s| s.trading_partner == "PVH BILLING DUTY REVERSAL"}).not_to be_nil
    end

    it "sends xml with charges reversed where original did not include a purpose" do
      existing_xml_data.gsub!(/<Purpose>.*<\/Purpose>/, "")
      invoice_snapshot = subject.json_child_entities(entry_snapshot, "BrokerInvoice").last
      expect_any_instance_of(Attachment).to receive(:download_to_tempfile).and_yield xml_tempfile
      expect(subject).to receive(:duty_invoice_number).and_return "DUTYINV"

      expect(subject.generate_and_send_reversal entry_snapshot, invoice_snapshot, new_invoice, "DUTY").to eq true

      expect(captured_xml.length).to eq 1

      x = REXML::Document.new(captured_xml.first).root
      expect(x).to have_xpath_value("GenericInvoices/GenericInvoice/InvoiceHeader/InvoiceNumber", "DUTYINV")

      lines = REXML::XPath.each(x, "GenericInvoices/GenericInvoice/InvoiceDetails/InvoiceLineItem[ChargeField/Type/Code = 'E063']").to_a
      expect(lines.length).to eq 2

      expect(lines[0]).not_to be_nil
      expect(lines[0]).to have_xpath_value("ChargeField/Purpose", "Decrement")
      expect(lines[0]).to have_xpath_value("ChargeField/Value", "100.0")

      # because the original file was missing the Purpose tags (after we stripped them from the data above),
      # both ChargeField purposes should be Decrement values
      expect(lines[1]).not_to be_nil
      expect(lines[1]).to have_xpath_value("ChargeField/Purpose", "Decrement")
      expect(lines[1]).to have_xpath_value("ChargeField/Value", "200.0")
    end

    it "doesn't send if original invoice already reversed" do
      invoice_snapshot = subject.json_child_entities(entry_snapshot, "BrokerInvoice").last

      broker_invoice_1.sync_records.create! trading_partner: "PVH BILLING DUTY REVERSAL", sent_at: Time.zone.now
      expect(subject.generate_and_send_reversal entry_snapshot, invoice_snapshot, new_invoice, "DUTY").to eq false
    end

    it "doesn't send if original invoice can't be found" do
      broker_invoice_1.update! invoice_total: BigDecimal("100.00")
      invoice_snapshot = subject.json_child_entities(entry_snapshot, "BrokerInvoice").last

      expect(subject.generate_and_send_reversal entry_snapshot, invoice_snapshot, new_invoice, "DUTY").to eq false
    end

    it "doesn't send if original invoice has different charge codes" do
      broker_invoice_1.broker_invoice_lines.first.update! charge_code: "9999"

      invoice_snapshot = subject.json_child_entities(entry_snapshot, "BrokerInvoice").last

      expect(subject.generate_and_send_reversal entry_snapshot, invoice_snapshot, new_invoice, "DUTY").to eq false
    end
  end
end