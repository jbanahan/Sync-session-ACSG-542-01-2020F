describe OpenChain::CustomHandler::Descartes::DescartesBasicShipmentXmlParser do

  let (:xml_data) { IO.read 'spec/fixtures/files/descartes_shipment.xml' }
  let (:xml) { REXML::Document.new xml_data }
  let (:user) { FactoryBot(:user) }

  describe "parse_file" do
    let! (:importer) {
      i = FactoryBot(:importer, system_code: "SYSCODE")
      i.system_identifiers.create! system: "eCellerate", code: "INTIN"
      i
    }
    let (:inbound_file) { InboundFile.new s3_path: "file.xml", s3_bucket: "bucket" }

    before :each do
      allow(subject).to receive(:inbound_file).and_return inbound_file
    end

    context "with valid data" do

      let! (:port_entry) { Port.create! schedule_d_code: "1001", name: "Port of Entry" }
      let! (:port_lading) { Port.create! schedule_k_code: "57078", name: "Port of Lading" }
      let! (:port_discharge) { Port.create! schedule_d_code: "1002", name: "Port of Discharge" }
      let! (:port_delivery) { Port.create! schedule_d_code: "1003", name: "Port of Delivery" }

      it "parses a file into a shipment" do
        s = subject.parse xml, user
        expect(s).not_to be_nil
        expect(s).to be_persisted
        s.reload

        expect(s.importer).to eq importer
        expect(s.reference).to eq "SYSCODE-LMDLSZ18080052"
        expect(s.last_exported_from_source).to eq Time.zone.parse("2018-08-07T14:59:13.00-05:00")
        expect(s.last_file_bucket).to eq "bucket"
        expect(s.last_file_path).to eq "file.xml"
        expect(s.house_bill_of_lading).to eq "LMDLSZ18080052"
        expect(s.master_bill_of_lading).to eq "ONEYSZPU61865401"
        expect(s.mode).to eq "Ocean"
        expect(s.vessel).to eq "MADRID BRIDGE"
        expect(s.voyage).to eq "002E"
        expect(s.booking_number).to eq "ABC123"
        expect(s.est_departure_date).to eq Date.new(2018, 8, 8)
        expect(s.departure_date).to eq Date.new(2018, 8, 9)
        expect(s.est_arrival_port_date).to eq Date.new(2018, 9, 6)

        expect(s.number_of_packages).to eq 492
        expect(s.number_of_packages_uom).to eq "CTN"
        expect(s.description_of_goods).to eq "DESCRIPTION OF GOODS"
        expect(s.gross_weight).to eq BigDecimal("4920")
        expect(s.volume).to eq BigDecimal("61.71")

        expect(s.receipt_location).to eq "SHANTOU"
        expect(s.destination_port).to eq port_entry
        expect(s.lading_port).to eq port_lading
        expect(s.unlading_port).to eq port_discharge
        expect(s.final_dest_port).to eq port_delivery

        expect(s.containers.length).to eq 1

        c = s.containers.first
        expect(c.container_number).to eq "SEGU5873980"
        expect(c.seal_number).to eq "CNAA34101"
        expect(c.container_size).to eq "9400"

        expect(inbound_file.company).to eq importer
        expect(inbound_file).to have_identifier :house_bill, "LMDLSZ18080052"
        expect(inbound_file).to have_identifier :master_bill, "ONEYSZPU61865401"
        expect(inbound_file).to have_identifier :container_number, "SEGU5873980"

        expect(s.entity_snapshots.length).to eq 1
        expect(s.entity_snapshots.first.user).to eq user
        expect(s.entity_snapshots.first.context).to eq "file.xml"
      end

      it "updates exising shipment" do
        shipment = Shipment.create! importer_id: importer.id, house_bill_of_lading: "LMDLSZ18080052", reference: "REF"

        s = subject.parse xml, user
        expect(s).not_to be_nil

        expect(s).to eq shipment
        shipment.reload

        expect(shipment.master_bill_of_lading).to eq "ONEYSZPU61865401"
      end

      it "skips shipments that were received after transaction date from XML" do
        shipment = Shipment.create! importer_id: importer.id, house_bill_of_lading: "LMDLSZ18080052", reference: "REF", last_exported_from_source: Time.zone.parse("2019-01-01 12:00")
        expect( subject.parse xml, user ).to be_nil
        shipment.reload
        expect(shipment.entity_snapshots.length).to eq 0
      end
    end

    context "with xml errors" do
      it "rejects if house bill is missing" do
        xml_data.gsub!("<HouseBillNumber>LMDLSZ18080052</HouseBillNumber>", "")
        expect { subject.parse xml, user }.to raise_error StandardError

        expect(inbound_file).to have_reject_message "All eCellerate shipment XML files must have a HouseBillNumber element."
      end

      it "rejects if transaction date time is missing" do
        xml_data.gsub!("<TransactionDateTime>2018-08-07T14:59:13.00-05:00</TransactionDateTime>", "")
        expect { subject.parse xml, user }.to raise_error StandardError

        expect(inbound_file).to have_reject_message "All eCellerate shipment XML files must have a TransactionDateTime element."
      end

      it "rejects if importer party is missing" do
        xml_data.gsub!("<PartyType>Importer</PartyType>", "")
        expect { subject.parse xml, user }.to raise_error StandardError

        expect(inbound_file).to have_reject_message "All eCellerate shipment XML files must have an Importer Party element."
      end

      it "errors if importer can't be found via PartyCode" do
        importer.system_identifiers.destroy_all

        expect { subject.parse xml, user }.to raise_error StandardError

        expect(inbound_file).to have_error_message "Failed to find importer with eCellerate code of 'INTIN'."
      end

      it "errors if importer does not have a system code set up" do
        importer.update_attributes! system_code: ""

        expect { subject.parse xml, user }.to raise_error StandardError

        expect(inbound_file).to have_error_message "eCellerate Importer 'INTIN' must have a VFI Track system code configured."
      end

      it "rejects if xml is missing PartyCode for Importer party" do
        xml_data.gsub!("<PartyCode>INTIN</PartyCode>", "")
        expect { subject.parse xml, user }.to raise_error StandardError

        expect(inbound_file).to have_reject_message "All eCellerate shipment XML files must have an Importer Party element with a PartyCode element."
      end
    end

    context "with special system code translations" do
      it "translates JJILL system code to JILL for reference number prefix" do
        importer.update_attributes! system_code: "JJILL"
        s = subject.parse xml, user
        expect(s.reference).to eq "JILL-LMDLSZ18080052"
      end
    end
  end
end
