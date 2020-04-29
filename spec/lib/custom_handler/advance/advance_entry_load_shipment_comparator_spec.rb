describe OpenChain::CustomHandler::Advance::AdvanceEntryLoadShipmentComparator do

  let (:advance) { Company.new system_code: "ADVAN" }
  let (:us) {
    c = Country.new
    c.iso_code = "US"
    c
  }
  let (:ca) {
    c = Country.new
    c.iso_code = "CA"
    c
  }
  let (:advance_shipment) { Shipment.new importer: advance, reference: "REF", country_import: us }
  let (:cq) { Company.new system_code: "CQ"}
  let (:cq_shipment) { Shipment.new importer: cq, reference: "REF", country_import: ca }

  describe "accept?" do
    subject { described_class }

    it "accepts ADVAN shipments" do
      expect(subject.accept? EntitySnapshot.new(recordable: advance_shipment)).to eq true
    end

    it "accepts CQ shipments" do
      expect(subject.accept? EntitySnapshot.new(recordable: cq_shipment)).to eq true
    end

    it "does not accept other importers" do
      c = Company.new system_code: "OTHER"
      shipment = Shipment.new importer: c

      expect(subject.accept? EntitySnapshot.new(recordable: shipment)).to eq false
    end
  end

  describe "determine_entry_system" do
    it "returns kewill for all US shipments" do
      expect(subject.determine_entry_system advance_shipment).to eq :kewill
    end

    it "returns fenix for all CA shipments" do
      expect(subject.determine_entry_system cq_shipment).to eq :fenix
    end

    it "errors for any other country" do
      c = Country.new
      c.iso_code = "CN"
      advance_shipment.country_import = c

      expect { subject.determine_entry_system advance_shipment }.to raise_error "Invalid Import Country 'CN' for Shipment 'REF'."
    end
  end

  describe "trading_partner" do
    let (:shipment) { Shipment.new }

    it "returns 'Kewill Entry' for kewill shipments" do
      expect(subject).to receive(:determine_entry_system).with(shipment).and_return :kewill
      expect(subject.trading_partner shipment).to eq "Kewill Entry"
    end

    it "returns 'Fenix Entry' for fenix shipments" do
      expect(subject).to receive(:determine_entry_system).with(shipment).and_return :fenix
      expect(subject.trading_partner shipment).to eq "Fenix Entry"
    end
  end

  describe "generate_and_send_kewill" do
    let (:sync_record) { SyncRecord.new }
    let (:shipment) { Shipment.new reference: "REF"}

    it "generates and sends kewill xml" do
      # This method is just a straight callthrough to the Advan generator
      expect_any_instance_of(OpenChain::CustomHandler::Advance::AdvanceKewillShipmentEntryXmlGenerator).to receive(:generate_xml_and_send).with(shipment, sync_records: sync_record)
      subject.generate_and_send_kewill(shipment, sync_record)
    end
  end

  describe "generate_and_send_fenix" do
    let (:sync_record) { SyncRecord.new }
    let (:shipment) { Shipment.new reference: "REF"}

    it "generates and sends fenix data" do
      # This method is just a straight callthrough to the CQ generator
      expect_any_instance_of(OpenChain::CustomHandler::Advance::CarquestFenixNdInvoiceGenerator).to receive(:generate_invoice_and_send).with(shipment, sync_record)

      subject.generate_and_send_fenix(shipment, sync_record)
    end
  end
end