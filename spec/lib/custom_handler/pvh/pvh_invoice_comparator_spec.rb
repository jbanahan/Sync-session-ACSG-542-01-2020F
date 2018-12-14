describe OpenChain::CustomHandler::Pvh::PvhInvoiceComparator do

  let (:pvh) {
    Company.new system_code: "PVH"
  }

  let (:invoice) {
    i = Invoice.new 
    i.importer = pvh
    i.consignee = consignee
    i
  }

  let (:consignee) {
    c = Company.new
    a = Address.new
    a.country = ca
    c.addresses << a
    c
  }

  let (:ca) {
    Factory(:country, iso_code: "CA")
  }

  let (:snapshot) {
    s = EntitySnapshot.new
    s.recordable = invoice

    s
  }

  describe "accept?" do
    subject { described_class }

    it "accepts PVH canadian invoice snapshots" do
      expect(subject.accept? snapshot).to eq true
    end

    it "does not accept non-canadian invoices" do
      consignee.addresses.first.country = Factory(:country, iso_code: "US")
      expect(subject.accept? snapshot).to eq false
    end

    it "does not accept invoices without consignees" do
      invoice.consignee = nil
      expect(subject.accept? snapshot).to eq false
    end

    it "does not accept non-PVH invoices" do
      pvh.system_code = "NOTPVH"
      expect(subject.accept? snapshot).to eq false
    end
  end

  describe "send_invoice" do
    it "sends an invoice that has not been sent to Fenix" do
      s = nil
      expect(subject).to receive(:generate_and_send_ca_invoice) do |inv, sync_record|
        expect(inv).to be invoice
        expect(sync_record).to be_a(SyncRecord)
        s = sync_record
      end
      now = Time.zone.parse("2018-09-01 12:00")
      Timecop.freeze(now) { subject.send_invoice invoice }
      

      expect(s.sent_at).to eq now
      expect(s.confirmed_at).to eq (now + 1.minute)
      expect(s.trading_partner).to eq "Fenix 810"
      expect(s).to be_persisted
    end

    it "does not send an invoice that has already been sent" do
      invoice.sync_records.build trading_partner: "Fenix 810", sent_at: Time.zone.now

      expect(subject).not_to receive(:generate_and_send_ca_invoice)
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