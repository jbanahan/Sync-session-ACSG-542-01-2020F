describe OpenChain::CustomHandler::Vandegrift::KewillInvoiceCiLoadComparator do

  let (:importer) {
    with_customs_management_id(Factory(:company), "CUST")
  }

  let (:invoice) {
    i = Invoice.new
    i.importer = importer
    i
  }

  let (:snapshot) {
    s = EntitySnapshot.new
    s.recordable = invoice

    s
  }

  describe "accept?" do
    subject { described_class }

    let! (:xref) { DataCrossReference.create! cross_reference_type: DataCrossReference::INVOICE_CI_LOAD_CUSTOMERS, key: "CUST" }

    it "accepts customers with invoice generator cross reference set up" do
      expect(subject.accept? snapshot).to eq true
    end

    it 'does not accept snapshots for customers without xrefs' do
      xref.destroy
      expect(subject.accept? snapshot).to eq false
    end

    it "does not accept snapshots for importers without kewill customer numbers" do
      importer.system_identifiers.destroy_all
      expect(subject.accept? snapshot).to eq false
    end

    it "does not accept non-Invoice snapshots" do
      snapshot.recordable_type = 'Shipment'
      expect(subject.accept? snapshot).to eq false
    end
  end

  describe "send_invoice" do

    class FakeInvoiceGenerator
      def generate_and_send_invoice invoice, sync_record
        nil
      end
    end

    let! (:xref) { DataCrossReference.create! cross_reference_type: DataCrossReference::INVOICE_CI_LOAD_CUSTOMERS, key: "CUST" }

    it "sends an invoice that has not been sent to Fenix" do
      s = nil
      expect_any_instance_of(OpenChain::CustomHandler::Vandegrift::KewillInvoiceGenerator).to receive(:generate_and_send_invoice) do |inst, inv, sync_record|
        expect(inv).to be invoice
        expect(sync_record).to be_a(SyncRecord)
        s = sync_record
      end
      now = Time.zone.parse("2018-09-01 12:00")
      Timecop.freeze(now) { subject.send_invoice invoice }

      expect(s.sent_at).to eq now
      expect(s.confirmed_at).to eq (now + 1.minute)
      expect(s.trading_partner).to eq "CI LOAD"
      expect(s).to be_persisted
    end

    it "does not send an invoice that has already been sent" do
      invoice.sync_records.build trading_partner: "CI LOAD", sent_at: Time.zone.now

      expect_any_instance_of(OpenChain::CustomHandler::Vandegrift::KewillInvoiceGenerator).not_to receive(:generate_and_send_invoice)
      subject.send_invoice invoice
    end

    it "allows alternate generator classes to be specified by the xref" do
      xref.update_attributes! value: FakeInvoiceGenerator.to_s

      expect_any_instance_of(FakeInvoiceGenerator).to receive(:generate_and_send_invoice)
      subject.send_invoice invoice
    end
  end

  describe "compare" do
    subject { described_class }

    before :each do
      invoice.save!
    end

    it "sends an invoice" do
      expect_any_instance_of(subject).to receive(:send_invoice)
      subject.compare nil, invoice.id, nil, nil, nil, nil, nil, nil
    end
  end
end