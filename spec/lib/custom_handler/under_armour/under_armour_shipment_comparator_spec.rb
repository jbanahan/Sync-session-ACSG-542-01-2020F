describe OpenChain::CustomHandler::UnderArmour::UnderArmourShipmentComparator do

  subject { described_class }

  describe "accept?" do

    let (:importer) {
      c = Company.new
      c.importer = true
      c.system_code = "UNDAR"
      c
    }

    let (:shipment) { 
      s = Shipment.new
      s.importer = importer
      s
    }

    let (:snapshot) {
      s = EntitySnapshot.new
      s.recordable = shipment

      s
    }

    it "accepts shipment snapshots for under armour" do
      expect(subject.accept? snapshot).to eq true
    end

    it "does not accept non-UA shipment snapshots" do
      importer.system_code = "NOT-UNDAR"
      expect(subject.accept? snapshot).to eq false
    end

    it "does not accept shipments without importers" do
      shipment.importer = nil
      expect(subject.accept? snapshot).to eq false
    end

    it "does not accept snapshots for non-shipments" do
      e = Entry.new
      e.importer = importer

      snapshot.recordable = e
      expect(subject.accept? snapshot).to eq false
    end

    it "does not accept snapshots when 'UA EEM Conversion' custom feature is enabled" do 
      ms = stub_master_setup
      expect(ms).to receive(:custom_feature?).with("UA EEM Conversion").and_return true

      expect(subject.accept? snapshot).to eq false
    end
  end

  describe "compare" do
    let (:generator) {
      instance_double(OpenChain::CustomHandler::UnderArmour::UnderArmourFenixInvoiceGenerator)
    }

    let (:ua) { Factory(:importer, system_code: "UNDAR") }
    let (:shipment) { Factory(:shipment, importer: ua) }

    it "sends fenix invoice file" do
      expect(subject).to receive(:invoice_generator).and_return generator
      expect(generator).to receive(:generate_and_send_invoice).with(shipment)

      now = Time.zone.now
      Timecop.freeze(now) do 
        subject.compare nil, shipment.id, nil, nil, nil, nil, nil, nil
      end

      shipment.reload

      expect(shipment.sync_records.length).to eq 1
      sr = shipment.sync_records.first
      expect(sr.trading_partner).to eq "FENIX-810"
      expect(sr.sent_at.to_i).to eq now.to_i
      expect(sr.confirmed_at.to_i).to eq (now + 1.minute).to_i
    end

    it "does not send if a sync record is already present" do
      shipment.sync_records.create! sent_at: Time.zone.now, trading_partner: "FENIX-810"

      expect(subject).not_to receive(:invoice_generator)
      subject.compare nil, shipment.id, nil, nil, nil, nil, nil, nil
    end

    it "does send if sync record has blank sent_at" do
      expect(subject).to receive(:invoice_generator).and_return generator
      expect(generator).to receive(:generate_and_send_invoice).with(shipment)
      shipment.sync_records.create! trading_partner: "FENIX-810"

      subject.compare nil, shipment.id, nil, nil, nil, nil, nil, nil
    end
  end
end