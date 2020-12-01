describe OpenChain::CustomHandler::Generator315::Isf315XmlGenerator do
  def milestone_update code, date, sync_record = nil
    OpenChain::CustomHandler::Generator315::Shared315Support::MilestoneUpdate.new code, date, sync_record
  end

  describe "generate_and_send_315s" do
    let (:config) { MilestoneNotificationConfig.new output_style: MilestoneNotificationConfig::OUTPUT_STYLE_STANDARD, customer_number: "config_cust" }
    let(:isf) do
      FactoryBot(:security_filing, host_system_file_number: "ref", importer_account_code: "cust", transaction_number: "trans",
                                transport_mode_code: "10", scac: "SCAC", vessel: "VES", voyage: "VOY", entry_port_code: "1234",
                                lading_port_code: "56789", unlading_port_code: "0987", master_bill_of_lading: "M\nB", house_bills_of_lading: "H\nB",
                                container_numbers: "C\nN", po_numbers: "P\nO", first_accepted_date: "2015-03-01 08:00")
    end
    let!(:port_entry) { FactoryBot(:port, schedule_d_code: "1234", name: "Entry Port") }
    let!(:port_unlading) { FactoryBot(:port, schedule_d_code: "0987", name: "Unlading Port") }
    let!(:port_lading) { FactoryBot(:port, schedule_k_code: "56789", name: "Lading Port") }

    it "generates and sends data" do
      t = Time.zone.now
      cap = nil
      fake_data = double
      allow(fake_data).to receive(:event_code).and_return "code"
      allow(fake_data).to receive(:event_date).and_return t
      sync_record = SyncRecord.new
      allow(fake_data).to receive(:sync_record).and_return sync_record
      expect(sync_record).to receive(:save!)
      expect(subject).to receive(:generate_and_send_document) { |cust_no, data, testing|
        expect(cust_no).to eq "config_cust"
        expect(testing).to be_falsey
        cap = data
      }.and_yield(fake_data)

      subject.generate_and_send_315s config, isf, [milestone_update("code", t.iso8601)], false

      # Verify the correct data was created (actual xml generation is purview of the generator support spec)
      d = cap.first
      expect(d.broker_reference).to eq "ref"
      expect(d.entry_number).to eq "trans"
      expect(d.ship_mode).to eq "10"
      expect(d.carrier_code).to eq "SCAC"
      expect(d.vessel).to eq "VES"
      expect(d.voyage_number).to eq "VOY"
      expect(d.port_of_entry).to eq "1234"
      expect(d.port_of_entry_location).to eq port_entry
      expect(d.port_of_lading).to eq "56789"
      expect(d.port_of_lading_location).to eq port_lading
      expect(d.port_of_unlading).to eq "0987"
      expect(d.port_of_unlading_location).to eq port_unlading
      expect(d.master_bills).to eq ["M", "B"]
      expect(d.container_numbers).to eq ["C", "N"]
      expect(d.house_bills).to eq ["H", "B"]
      expect(d.po_numbers).to eq "P\nO"
      expect(d.event_code).to eq "code"
      expect(d.event_date).to eq t.iso8601
      expect(d.datasource).to eq "isf"
    end

    it "splits data by master bill" do
      config.output_style = MilestoneNotificationConfig::OUTPUT_STYLE_MBOL
      cap = []
      expect(subject).to receive(:generate_and_send_document) do |_cust_no, data, _testing|
        cap.push(*data)
      end
      subject.generate_and_send_315s config, isf, [milestone_update("code", Time.zone.now)], false

      expect(cap.size).to eq 2
      expect(cap[0].master_bills).to eq ["M"]
      expect(cap[1].master_bills).to eq ["B"]
    end

    it "splits data by house bill" do
      config.output_style = MilestoneNotificationConfig::OUTPUT_STYLE_HBOL
      cap = []
      expect(subject).to receive(:generate_and_send_document) do |_cust_no, data, _testing|
        cap.push(*data)
      end
      subject.generate_and_send_315s config, isf, [milestone_update("code", Time.zone.now)], false

      expect(cap.size).to eq 2
      expect(cap[0].house_bills).to eq ["H"]
      expect(cap[1].house_bills).to eq ["B"]
    end

    it "splits data by mbol container" do
      config.output_style = MilestoneNotificationConfig::OUTPUT_STYLE_MBOL_CONTAINER_SPLIT
      cap = []
      expect(subject).to receive(:generate_and_send_document) do |_cust_no, data, _testing|
        cap.push(*data)
      end
      subject.generate_and_send_315s config, isf, [milestone_update("code", Time.zone.now)], false

      expect(cap.size).to eq 4
      expect(cap[0].master_bills).to eq ["M"]
      expect(cap[0].container_numbers).to eq ["C"]
      expect(cap[1].master_bills).to eq ["M"]
      expect(cap[1].container_numbers).to eq ["N"]
      expect(cap[2].master_bills).to eq ["B"]
      expect(cap[2].container_numbers).to eq ["C"]
      expect(cap[3].master_bills).to eq ["B"]
      expect(cap[3].container_numbers).to eq ["N"]
    end

    it "handles multiple milestones" do
      cap = []
      expect(subject).to receive(:generate_and_send_document) do |_cust_no, data, _testing|
        cap.push(*data)
      end
      subject.generate_and_send_315s config, isf, [milestone_update("code1", Time.zone.now), milestone_update("code2", Time.zone.now)], false
      expect(cap.size).to eq 2
      expect(cap[0].event_code).to eq "code1"
      expect(cap[1].event_code).to eq "code2"
    end
  end

end
