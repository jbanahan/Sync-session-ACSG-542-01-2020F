describe OpenChain::CustomHandler::Vandegrift::KewillMultiShipmentEntryXmlGenerator do

  let (:xml_generator) { instance_double(OpenChain::CustomHandler::Vandegrift::KewillShipmentEntryXmlGenerator) }
  let (:xml_output) { instance_double(REXML::Document) }
  let (:importer) { FactoryBot(:importer, system_code: "IMP") }
  let (:cdefs) { described_class.new.cdefs }
  let (:run_opts) { {"importer_system_code" => "IMP"} }
  let (:us) { FactoryBot(:country, iso_code: "US")}

  subject { described_class.new xml_generator }

  describe "find_generate_and_send" do

    let! (:unsynced_shipment) {
      shipment = FactoryBot(:shipment, importer: importer, master_bill_of_lading: "MBOL", importer_reference: "REF2", country_import: us)
      shipment.update_custom_value! cdefs[:shp_entry_prepared_date], Time.zone.now
      shipment
    }

    let! (:synced_shipment) {
      shipment = FactoryBot(:shipment, importer: importer, master_bill_of_lading: "MBOL", importer_reference: "REF1", country_import: us)
      shipment.update_custom_value! cdefs[:shp_entry_prepared_date], Time.zone.now
      shipment.sync_records.create! trading_partner: "Kewill Entry", sent_at: (Time.zone.now - 1.day)
      shipment
    }

    it "finds unsynced shipments, generates xml for them and sends them" do
      expect(xml_generator).to receive(:generate_xml_and_send) do |shipments, sync_records|
        expect(shipments.first).to eq synced_shipment
        expect(shipments.second).to eq unsynced_shipment
        expect(sync_records[:sync_records].length).to eq 2
      end

      expect(subject).to receive(:poll).and_yield((Time.zone.now - 1.hour), Time.zone.now)
      synced_sent_at = synced_shipment.sync_records.first.sent_at

      subject.find_generate_and_send(run_opts)

      unsynced_shipment.reload
      sr = unsynced_shipment.sync_records.first
      expect(sr.trading_partner).to eq "Kewill Entry"
      expect(sr.sent_at).not_to be_nil

      synced_shipment.reload
      sr = synced_shipment.sync_records.first
      # The sent at shouldn't have changed for the record that was already synced
      expect(sr.sent_at).to eq synced_sent_at
    end

    it "does not find synced shipments to combine if they are not US imports" do
      ca = FactoryBot(:country, iso_code: "CA")
      synced_shipment.update_attributes! country_import_id: ca.id

      expect(xml_generator).to receive(:generate_xml_and_send) do |shipments, sync_records|
        expect(shipments.length).to eq 1
        expect(shipments.first).to eq unsynced_shipment
        expect(sync_records[:sync_records].length).to eq 1
        expect(sync_records[:sync_records].first.syncable_id).to eq unsynced_shipment.id
      end

      expect(subject).to receive(:poll).and_yield((Time.zone.now - 1.hour), Time.zone.now)
      subject.find_generate_and_send(run_opts)
    end

    context "with no shipment sent" do
      after :each do
        expect(subject).to receive(:poll).and_yield((Time.zone.now - 1.hour), Time.zone.now)
        expect(subject).not_to receive(:generate_and_send)
        subject.find_generate_and_send(run_opts)
      end

      it "sends nothing if all shipments are already synced" do
        unsynced_shipment.sync_records.create! trading_partner: "Kewill Entry", sent_at: Time.zone.now
      end

      it "sends nothing shipment doesn't have Entry Prepared custom value" do
        unsynced_shipment.custom_values.destroy_all
      end

      it "sends nothing if shipment is cancelled" do
        unsynced_shipment.update_attributes! canceled_date: Time.zone.now
      end

      it "sends nothing if masterbill is blank" do
        unsynced_shipment.update_attributes! master_bill_of_lading: nil
      end

      it "sends nothing if updated at is prior to last job run" do
        unsynced_shipment.update_column :updated_at, (Time.zone.now - 1.year)
      end

      it "sends nothing if system code doesn't match importer" do
        run_opts["importer_system_code"] = "TEST"
      end

      it "sends nothing if unsynced shipment is not for US" do
        ca = FactoryBot(:country, iso_code: "CA")
        unsynced_shipment.update_attributes! country_import_id: ca.id
      end
    end


  end
end