describe OpenChain::CustomHandler::Generator315::Entry315XmlGenerator do

  def milestone_update code, date, sync_record = nil
    OpenChain::CustomHandler::Generator315::Shared315Support::MilestoneUpdate.new code, date, sync_record
  end

  describe "create_315_data" do
    let(:entry) do
      FactoryBot(:entry, broker_reference: "REF", entry_number: "ENT", transport_mode_code: "10", fcl_lcl: "F", carrier_code: "CAR",
                      vessel: "VES", voyage: "VOY", entry_port_code: "1234", lading_port_code: "65433", unlading_port_code: "9876",
                      po_numbers: "ABC\n DEF")
    end
    let(:milestone) { milestone_update('code', Time.zone.now.to_date, SyncRecord.new) }
    let(:canada) { FactoryBot(:country, iso_code: 'CA')}
    let!(:port_entry) { FactoryBot(:port, schedule_d_code: "1234", name: "Entry Port") }
    let!(:port_unlading) { FactoryBot(:port, schedule_d_code: "9876", name: "Unlading Port") }
    let!(:port_lading) { FactoryBot(:port, schedule_k_code: "65433", name: "Lading Port") }

    it "extracts data from entry for 315 creation" do
      d = subject.send(:create_315_data, entry, {master_bills: ["ABC"], container_numbers: ["CON"], house_bills: ["HAWB"],
                                                 cargo_control_numbers: ["CARGO", "CARGO2"]}, milestone)

      expect(d.broker_reference).to eq "REF"
      expect(d.entry_number).to eq "ENT"
      expect(d.ship_mode).to eq "10"
      expect(d.service_type).to eq "F"
      expect(d.carrier_code).to eq "CAR"
      expect(d.vessel).to eq "VES"
      expect(d.voyage_number).to eq "VOY"
      expect(d.port_of_entry).to eq "1234"
      expect(d.port_of_entry_location).to eq port_entry
      expect(d.port_of_lading).to eq "65433"
      expect(d.port_of_lading_location).to eq port_lading
      expect(d.port_of_unlading).to eq "9876"
      expect(d.port_of_unlading_location).to eq port_unlading
      expect(d.cargo_control_number).to eq "CARGO\n CARGO2"
      expect(d.master_bills).to eq ["ABC"]
      expect(d.container_numbers).to eq ["CON"]
      expect(d.house_bills).to eq ["HAWB"]
      expect(d.po_numbers).to eq ["ABC", "DEF"]
      expect(d.event_code).to eq 'code'
      expect(d.event_date).to eq Time.zone.now.to_date
      expect(d.sync_record).to eq milestone.sync_record
      expect(d.datasource).to eq "entry"
    end

    it "uses unlocode for Canadian entries" do
      port = Port.new(cbsa_port: "1234", unlocode: "CACOD")
      entry.assign_attributes import_country: canada, ca_entry_port: port
      d = subject.send(:create_315_data, entry, {}, milestone)

      expect(d.port_of_entry).to eq "CACOD"
      expect(d.port_of_entry_location).to eq port
    end

    it "raises an error if the Canadian Port does not have an associated UN Locode" do
      entry.assign_attributes import_country: canada, ca_entry_port: Port.new(cbsa_port: "1234")
      expect {subject.send(:create_315_data, entry, {}, milestone)}.to raise_error "Missing UN Locode for Canadian Port Code 1234."
    end

    it "doesn't raise error if Canadian Port is unset" do
      entry.assign_attributes import_country: canada
      d = subject.send(:create_315_data, entry, {}, milestone)
      expect(d.port_of_entry).to be_nil
    end
  end
end
