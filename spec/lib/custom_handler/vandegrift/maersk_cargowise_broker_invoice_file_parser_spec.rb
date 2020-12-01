describe OpenChain::CustomHandler::Vandegrift::MaerskCargowiseBrokerInvoiceFileParser do

  describe "parse" do
    let (:log) { InboundFile.new }
    let (:test_data) { IO.read('spec/fixtures/files/maersk_broker_invoice.xml') }

    before do
      allow(subject).to receive(:inbound_file).and_return log
    end

    def make_document xml_str
      doc = Nokogiri::XML xml_str
      doc.remove_namespaces!
      doc
    end

    it "creates a broker invoice" do
      entry = FactoryBot(:entry, broker_reference: "BQMJ01119290922", source_system: Entry::CARGOWISE_SOURCE_SYSTEM, total_duty: 5.55, total_taxes: 22.22)
      country = FactoryBot(:country, iso_code: 'US')

      subject.parse make_document(test_data), { key: "the_key", bucket: "the_bucket" }

      entry.reload
      expect(entry.broker_invoices.length).to eq 1
      expect(entry.broker_invoice_total).to eq BigDecimal("270.59")
      expect(entry.total_duty_direct).to eq BigDecimal("27.77")

      inv = entry.broker_invoices.first
      expect(inv.invoice_number).to eq "BQMJ01119290555"
      expect(inv.source_system).to eq Entry::CARGOWISE_SOURCE_SYSTEM
      expect(inv.invoice_date).to eq Time.zone.parse("2019-04-15").to_date
      expect(inv.invoice_total).to eq BigDecimal("270.59")
      expect(inv.customer_number).to eq "US00847996"
      expect(inv.bill_to_name).to eq "THE CATO CORPORATION"
      expect(inv.bill_to_address_1).to eq "DBA ANWUZHI IMPORTS"
      expect(inv.bill_to_address_2).to eq "8100 DENMARK RD"
      expect(inv.bill_to_city).to eq "CHARLOTTE"
      expect(inv.bill_to_state).to eq "NC"
      expect(inv.bill_to_zip).to eq "28273-5975"
      expect(inv.bill_to_country_id).to eq country.id
      expect(inv.last_file_path).to eq "the_key"
      expect(inv.last_file_bucket).to eq "the_bucket"
      expect(inv.currency).to eq "CAD"

      expect(inv.broker_invoice_lines.length).to eq 4

      inv_line_1 = inv.broker_invoice_lines[0]
      expect(inv_line_1.charge_code).to eq "201"
      expect(inv_line_1.charge_amount).to eq BigDecimal("0.00")
      expect(inv_line_1.charge_description).to eq "CUSTOMS DEFERRED"

      inv_line_2 = inv.broker_invoice_lines[1]
      expect(inv_line_2.charge_code).to eq "600"
      expect(inv_line_2.charge_amount).to eq BigDecimal("83.00")
      expect(inv_line_2.charge_description).to eq "CUSTOMS ENTRY SERVICES"

      inv_line_3 = inv.broker_invoice_lines[2]
      expect(inv_line_3.charge_code).to eq "550"
      expect(inv_line_3.charge_amount).to eq BigDecimal("17.59")
      expect(inv_line_3.charge_description).to eq "DUTY REDUCTION PROGRAM"

      inv_line_4 = inv.broker_invoice_lines[3]
      expect(inv_line_4.charge_code).to eq "690"
      expect(inv_line_4.charge_amount).to eq BigDecimal("170.00")
      expect(inv_line_4.charge_description).to eq "GOVT AGENCY FORMS-FDA,FCC CFIA."

      expect(log).to have_identifier :broker_reference, "BQMJ01119290922", Entry, entry.id
      expect(log).to have_identifier :invoice_number, "BQMJ01119290555", BrokerInvoice, inv.id

      expect(log).to have_info_message "Broker invoice successfully processed."
      expect(log).not_to have_info_message "Cargowise-sourced entry matching Broker Reference 'BQMJ01119290922' was not found, so a new entry was created."
    end

    it "updates an existing broker invoice" do
      entry = FactoryBot(:entry, broker_reference: "BQMJ01119290922", source_system: Entry::CARGOWISE_SOURCE_SYSTEM)

      exist_inv = entry.broker_invoices.build(invoice_number: "BQMJ01119290555", suffix: "this field isn't updated by the parser and shouldn't be messed with")
      exist_line = exist_inv.broker_invoice_lines.build(charge_code: "bogus", charge_description: "bogus", charge_amount: BigDecimal(5))
      entry.broker_invoices.build(invoice_number: "BQMJ01119290556", invoice_total: BigDecimal("55.44"), invoice_date: Date.new(2019, 5, 5))
      entry.save!

      subject.parse make_document(test_data)

      entry.reload
      expect(entry.broker_invoices.length).to eq 2
      expect(entry.broker_invoice_total).to eq BigDecimal("326.03")
      expect(entry.last_billed_date).to eq Time.zone.parse("2019-05-05").to_date

      inv = entry.broker_invoices.first
      expect(inv.id).to eq exist_inv.id
      expect(inv.suffix).to eq "this field isn't updated by the parser and shouldn't be messed with"
      expect(inv.invoice_number).to eq "BQMJ01119290555"
      expect(inv.invoice_date).to eq Time.zone.parse("2019-04-15").to_date
      expect(inv.invoice_total).to eq BigDecimal("270.59")

      # Existing line should have been removed.  If it hadn't been, this would be 5, not 4.
      expect(inv.broker_invoice_lines.length).to eq 4
      expect(inv.broker_invoice_lines.find {|line| line.id == exist_line.id }).to be_nil

      expect(log).to have_info_message "Broker invoice successfully processed."
    end

    it "creates new entry when entry not found" do
      subject.parse make_document(test_data)

      expect(Entry.where(broker_reference: "BQMJ01119290922", source_system: Entry::CARGOWISE_SOURCE_SYSTEM).first).not_to be_nil
      expect(BrokerInvoice.where(invoice_number: "BQMJ01119290555").first).not_to be_nil

      expect(log).to have_info_message "Cargowise-sourced entry matching Broker Reference 'BQMJ01119290922' was not found, so a new entry was created."
      expect(log).to have_info_message "Broker invoice successfully processed."
    end

    it "creates new entry when broker-ref-matching entry is of wrong type" do
      FactoryBot(:entry, broker_reference: "BQMJ01119290922", source_system: Entry::KEWILL_SOURCE_SYSTEM)

      subject.parse make_document(test_data)

      expect(Entry.where(broker_reference: "BQMJ01119290922", source_system: Entry::CARGOWISE_SOURCE_SYSTEM).first).not_to be_nil
      expect(BrokerInvoice.where(invoice_number: "BQMJ01119290555").first).not_to be_nil

      expect(log).to have_info_message "Cargowise-sourced entry matching Broker Reference 'BQMJ01119290922' was not found, so a new entry was created."
      expect(log).to have_info_message "Broker invoice successfully processed."
    end

    it "adds HST13 line" do
      test_data.gsub!(/HST12/, 'HST13')

      entry = FactoryBot(:entry, broker_reference: "BQMJ01119290922", source_system: Entry::CARGOWISE_SOURCE_SYSTEM, total_duty: 5.55, total_taxes: 22.22)

      subject.parse make_document(test_data), { key: "the_key", bucket: "the_bucket" }

      entry.reload
      inv = entry.broker_invoices.first
      expect(inv.broker_invoice_lines.length).to eq 5

      inv_line_hst13 = inv.broker_invoice_lines[4]
      expect(inv_line_hst13.charge_code).to eq "HST13"
      expect(inv_line_hst13.charge_amount).to eq BigDecimal("4.32")
      expect(inv_line_hst13.charge_description).to eq "VAT do you want?"

      expect(log).to have_info_message "Broker invoice successfully processed."
    end

    it "rejects when broker reference is missing" do
      test_data.gsub!(/Job/, 'Jorb')

      subject.parse make_document(test_data)

      expect(log).not_to have_info_message "Broker invoice successfully processed."
      expect(log).to have_reject_message "Broker Reference (Job Number) is required."
    end

    it "rejects when invoice number is missing" do
      test_data.gsub!(/JobInvoiceNumber/, 'JorbInvoyseNoumbur')

      FactoryBot(:entry, broker_reference: "BQMJ01119290922", source_system: Entry::CARGOWISE_SOURCE_SYSTEM)

      subject.parse make_document(test_data)

      expect(log).not_to have_info_message "Broker invoice successfully processed."
      expect(log).to have_reject_message "Invoice Number is required."
    end

    it "handles missing optional values" do
      test_data.gsub!(/CreateTime/, 'CreateTim')
      test_data.gsub!(/LocalTotal/, 'RemoteAllBran')
      test_data.gsub!(/Country/, 'Western')
      test_data.gsub!(/LocalAmount/, 'RemoteAmolehill')

      entry = FactoryBot(:entry, broker_reference: "BQMJ01119290922", source_system: Entry::CARGOWISE_SOURCE_SYSTEM)

      subject.parse make_document(test_data)

      entry.reload
      inv = entry.broker_invoices.first
      expect(inv.invoice_date).to be_nil
      expect(inv.invoice_total).to eq BigDecimal(0)
      expect(inv.bill_to_country_id).to be_nil

      inv_line_1 = inv.broker_invoice_lines[0]
      expect(inv_line_1.charge_amount).to eq BigDecimal(0)

      expect(log).to have_info_message "Broker invoice successfully processed."
    end

    it "handles invalid country code" do
      # No country record is saved here, making the code in the document invalid.
      entry = FactoryBot(:entry, broker_reference: "BQMJ01119290922", source_system: Entry::CARGOWISE_SOURCE_SYSTEM)

      subject.parse make_document(test_data)

      entry.reload
      inv = entry.broker_invoices.first
      expect(inv.bill_to_country_id).to be_nil

      expect(log).to have_info_message "Broker invoice successfully processed."
    end

    it "handles UniversalInterchange as root element" do
      entry = FactoryBot(:entry, broker_reference: "BQMJ01119290922", source_system: Entry::CARGOWISE_SOURCE_SYSTEM)

      subject.parse make_document("<UniversalInterchange><Body>#{test_data}</Body></UniversalInterchange>")

      entry.reload
      expect(entry.broker_invoices.length).to eq 1

      expect(log).to have_info_message "Broker invoice successfully processed."
    end

    it "clears entry total duty direct if not deferred duty invoice" do
      test_data.gsub!(/201/, '202')

      entry = FactoryBot(:entry,
                      broker_reference: "BQMJ01119290922",
                      source_system: Entry::CARGOWISE_SOURCE_SYSTEM,
                      total_duty: 5.55,
                      total_taxes: 22.22,
                      total_duty_direct: 333.33)

      subject.parse make_document(test_data), { key: "the_key", bucket: "the_bucket" }

      entry.reload
      expect(entry.total_duty_direct).to be_nil

      expect(log).to have_info_message "Broker invoice successfully processed."
    end
  end

end