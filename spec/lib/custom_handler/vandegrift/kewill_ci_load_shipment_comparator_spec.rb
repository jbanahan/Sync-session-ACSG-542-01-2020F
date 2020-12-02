describe OpenChain::CustomHandler::Vandegrift::KewillCiLoadShipmentComparator do

  subject { described_class }

  let (:importer) { with_customs_management_id(create(:importer), "TEST")}
  let (:shipment) { create(:shipment, importer: importer) }
  let (:cross_reference) {
    DataCrossReference.create! key: "TEST", cross_reference_type: DataCrossReference::SHIPMENT_CI_LOAD_CUSTOMERS
  }

  describe "accept?" do
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

  end

  describe "compare" do
    let (:custom_definition) {
      CustomDefinition.create! label: "Invoice Prepared Date", cdef_uid: "shp_invoice_prepared_date", module_type: "Shipment", data_type: "datetime"
    }

    context "with invoice prepared date" do
      before :each do
        shipment.update_custom_value! custom_definition, Time.zone.now
      end

      it "generates and sends an invoice if the shipment is invoice prepared and does not have a sent date" do
        shipment.update_custom_value! custom_definition, Time.zone.now

        expect_any_instance_of(OpenChain::CustomHandler::Vandegrift::KewillGenericShipmentCiLoadGenerator).to receive(:generate_and_send).with(shipment)

        now = Time.zone.now
        Timecop.freeze { subject.compare nil, shipment.id, nil, nil, nil, nil, nil, nil }

        shipment.reload

        sync = shipment.sync_records.find {|s| s.trading_partner == "CI LOAD" }
        expect(sync).not_to be_nil
        expect(sync.sent_at.to_i).to eq now.to_i
        expect(sync.confirmed_at.to_i).to eq (now + 1.minute).to_i
      end

      it "uses an alternate generator" do
        cross_reference.update_attributes! value: "OpenChain::CustomHandler::UnderArmour::UnderArmourFenixInvoiceGenerator"
        expect_any_instance_of(OpenChain::CustomHandler::UnderArmour::UnderArmourFenixInvoiceGenerator).to receive(:generate_and_send).with(shipment)
        subject.compare nil, shipment.id, nil, nil, nil, nil, nil, nil

        shipment.reload

        sync = shipment.sync_records.find {|s| s.trading_partner == "CI LOAD" }
        expect(sync).not_to be_nil
      end

      it "doesn't send if canceled date is set" do
        shipment.update_attributes! canceled_date: Time.zone.now
        subject.compare nil, shipment.id, nil, nil, nil, nil, nil, nil
        shipment.reload
        expect(shipment.sync_records.length).to eq 0
      end

      it "doesn't send if already synced" do
        shipment.sync_records.create! trading_partner: "CI LOAD", sent_at: Time.zone.now
        expect_any_instance_of(OpenChain::CustomHandler::Vandegrift::KewillGenericShipmentCiLoadGenerator).not_to receive(:generate_and_send)

        subject.compare nil, shipment.id, nil, nil, nil, nil, nil, nil
      end

      it "does send if already synced, but sent at is blank" do
        shipment.sync_records.create! trading_partner: "CI LOAD"
        expect_any_instance_of(OpenChain::CustomHandler::Vandegrift::KewillGenericShipmentCiLoadGenerator).to receive(:generate_and_send)

        subject.compare nil, shipment.id, nil, nil, nil, nil, nil, nil
      end

      it "sends if invoice prepared date is updated in the snapshot" do
        shipment.sync_records.create! trading_partner: "CI LOAD", sent_at: Time.zone.now
        expect(subject).to receive(:any_root_value_changed?).with("ob", "op", "ov", "nb", "np", "nv", [custom_definition.model_field_uid]).and_return true
        expect_any_instance_of(OpenChain::CustomHandler::Vandegrift::KewillGenericShipmentCiLoadGenerator).to receive(:generate_and_send).with(shipment)

        subject.compare nil, shipment.id, "ob", "op", "ov", "nb", "np", "nv"
      end
    end
  end
end