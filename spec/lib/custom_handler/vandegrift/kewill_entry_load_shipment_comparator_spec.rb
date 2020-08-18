
# This is admittedly strange, but since we need to generate the class from a constantized string, I
# believe this is the only way to accomplish that.
module OpenChain; class FakeKewillShipmentEntryXmlGenerator < OpenChain::CustomHandler::Vandegrift::KewillShipmentEntryXmlGenerator

  def generate_xml_and_send shipments, sync_records:

  end

end; end;

describe OpenChain::CustomHandler::Vandegrift::KewillEntryLoadShipmentComparator do

  let (:importer) { with_customs_management_id(Factory(:importer), "TEST") }
  let (:shipment) { Factory(:shipment, importer: importer) }
  let (:cross_reference) {
    DataCrossReference.create! key: "TEST", cross_reference_type: DataCrossReference::SHIPMENT_ENTRY_LOAD_CUSTOMERS
  }

  describe "accept?" do
    subject { described_class }

    let (:snapshot) {
      snapshot = EntitySnapshot.new recordable: shipment
    }

    it "accepts snapshots for shipments that are linked to importers set up with cross references" do
      cross_reference
      expect(subject.accept? snapshot).to eq true
    end

    it "does not accept shipments without a cross referenced importer" do
      expect(subject.accept? snapshot).to eq false
    end

    it "does not accept canceled shipments" do
      shipment.canceled_date = Time.zone.now
      cross_reference
      expect(subject.accept? snapshot).to eq false
    end

  end

  describe "compare" do
    let (:custom_definition) {
      CustomDefinition.create! label: "Entry Prepared", cdef_uid: "shp_entry_pepared", module_type: "Shipment", data_type: "datetime"
    }

    context "with entry prepared date" do
      before :each do
        shipment.update_custom_value! custom_definition, Time.zone.now
      end

      it "generates and sends an entry if the shipment is entry prepared and does not have a sent date" do
        expect_any_instance_of(OpenChain::CustomHandler::Vandegrift::KewillShipmentEntryXmlGenerator).to receive(:generate_xml_and_send).with(shipment, sync_records: instance_of(SyncRecord))

        now = Time.zone.now
        Timecop.freeze { subject.compare shipment, nil, nil, nil, nil, nil, nil }

        shipment.reload

        sync = shipment.sync_records.find {|s| s.trading_partner == "Kewill Entry" }
        expect(sync).not_to be_nil
        expect(sync.sent_at.to_i).to eq now.to_i
        expect(sync.confirmed_at.to_i).to eq (now + 1.minute).to_i
      end

      it "handles rollup as a value" do
        cross_reference.update! value: "Rollup"
        expect_any_instance_of(OpenChain::CustomHandler::Vandegrift::KewillShipmentEntryXmlGenerator).to receive(:generate_xml_and_send).with(shipment, sync_records: instance_of(SyncRecord))

        subject.compare shipment, nil, nil, nil, nil, nil, nil

        shipment.reload

        sync = shipment.sync_records.find {|s| s.trading_partner == "Kewill Entry" }
        expect(sync).not_to be_nil
      end

      it "uses an alternate generator" do
        cross_reference.update_attributes! value: "OpenChain::FakeKewillShipmentEntryXmlGenerator"
        expect_any_instance_of(OpenChain::FakeKewillShipmentEntryXmlGenerator).to receive(:generate_xml_and_send).with(shipment, sync_records: instance_of(SyncRecord))

        subject.compare shipment, nil, nil, nil, nil, nil, nil

        shipment.reload

        sync = shipment.sync_records.find {|s| s.trading_partner == "Kewill Entry" }
        expect(sync).not_to be_nil
      end

      it "doesn't send if Entry Prepared is blank" do
        shipment.update_custom_value! custom_definition, nil
        subject.compare shipment, nil, nil, nil, nil, nil, nil
        shipment.reload
        expect(shipment.sync_records.length).to eq 0
      end

      it "doesn't send if already synced" do
        shipment.sync_records.create! trading_partner: "Kewill Entry", sent_at: Time.zone.now
        expect(subject).to receive(:any_root_value_changed?).with('old-bucket', 'old-path', 'old-version', 'new-bucket', 'new-path', 'new-version', [custom_definition.model_field_uid]).and_return false
        expect(subject).not_to receive(:generate_and_send)

        subject.compare shipment, 'old-bucket', 'old-path', 'old-version', 'new-bucket', 'new-path', 'new-version'
      end

      it "does send if already synced, but sent at is blank" do
        shipment.sync_records.create! trading_partner: "Kewill Entry"
        expect(subject).to receive(:generate_and_send)
        subject.compare shipment, nil, nil, nil, nil, nil, nil
      end

      it "resends if Entry Prepared date changes in snapshot" do
        shipment.sync_records.create! trading_partner: "Kewill Entry", sent_at: Time.zone.now
        expect(subject).to receive(:any_root_value_changed?).with('old-bucket', 'old-path', 'old-version', 'new-bucket', 'new-path', 'new-version', [custom_definition.model_field_uid]).and_return true
        expect(subject).to receive(:generate_and_send)

        subject.compare shipment, 'old-bucket', 'old-path', 'old-version', 'new-bucket', 'new-path', 'new-version'
      end
    end
  end
end