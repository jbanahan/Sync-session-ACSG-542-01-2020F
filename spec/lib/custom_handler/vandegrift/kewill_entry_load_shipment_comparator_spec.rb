describe OpenChain::CustomHandler::Vandegrift::KewillEntryLoadShipmentComparator do

  let (:importer) { Factory(:importer, alliance_customer_number: "TEST")}
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
      
      def ftp_xml_expectations generator_class
        xml = instance_double(REXML::Document)
        expect(xml).to receive(:write).with(an_instance_of(Tempfile))
        expect_any_instance_of(generator_class).to receive(:generate_xml).with(shipment).and_return xml
        expect(subject).to receive(:ftp_sync_file).with(an_instance_of(Tempfile), an_instance_of(SyncRecord), hash_including({username: 'ecs', folder: "kewill_edi/to_kewill"}))
      end

      it "generates and sends an entry if the shipment is entry prepared and does not have a sent date" do
        ftp_xml_expectations(OpenChain::CustomHandler::Vandegrift::KewillShipmentEntryXmlGenerator)

        now = Time.zone.now
        Timecop.freeze { subject.compare shipment, nil, nil, nil, nil, nil, nil }

        shipment.reload

        sync = shipment.sync_records.find {|s| s.trading_partner == "Kewill Entry" }
        expect(sync).not_to be_nil
        expect(sync.sent_at.to_i).to eq now.to_i
        expect(sync.confirmed_at.to_i).to eq (now + 1.minute).to_i
      end

      it "uses an alternate generator" do
        # Just need to use a generator that has a method sig like 'generate_xml obj'..
        cross_reference.update_attributes! value: "OpenChain::CustomHandler::Crocs::Crocs210Generator"
        ftp_xml_expectations(OpenChain::CustomHandler::Crocs::Crocs210Generator)

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