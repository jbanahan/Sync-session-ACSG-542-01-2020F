require "spec_helper"

describe OpenChain::CustomHandler::Isf315Generator do

  describe "accepts?" do
    
    let(:isf) { SecurityFiling.new host_system_file_number: "ref", importer_account_code: "cust" }
    let(:mnc) { MilestoneNotificationConfig.new customer_number: "cust", enabled: true, output_style: "standard", module_type: "SecurityFiling" }

    context "with 'ISF 315' custom feature" do
      before :each do 
        ms = double("MasterSetup")
        allow(MasterSetup).to receive(:get).and_return ms
        allow(ms).to receive(:custom_feature?).with("ISF 315").and_return true
      end

      it "does not isf with missing importer account code" do
        isf.importer_account_code = ""
        mnc.save! 

        expect(subject.accepts? :save, isf).to be_falsey
      end

      it "accepts isf with all standard info" do
        mnc.save!
        expect(subject.accepts? :save, isf).to be_truthy
      end

      it "does not accept isf with no setups linked to customer account" do
        mnc.save!
        isf.importer_account_code = "ABC"
        expect(subject.accepts? :save, isf).to be_falsey
      end

      it "does not accept isf with disabled setup" do
        mnc.enabled = false
        mnc.save!

        expect(subject.accepts? :save, isf).to be_falsey
      end
    end

    it "does not accept isfs if 'ISF 315' custom feature is disabled" do
      mnc.save!
      expect(subject.accepts? :save, isf).to be_falsey
    end
  end

  describe "receive" do
    let(:isf) { SecurityFiling.create! host_system_file_number: "ref", importer_account_code: "cust", transaction_number: "trans",  transport_mode_code: "10", scac: "SCAC", vessel: "VES",
                                   voyage: "VOY", entry_port_code: "ENT", lading_port_code: "LAD", master_bill_of_lading: "M\nB", house_bills_of_lading: "H\nB", container_numbers: "C\nN", po_numbers: "P\nO", first_accepted_date: "2015-03-01 08:00"}
    let(:mnc) do 
      mnc = MilestoneNotificationConfig.new customer_number: "cust", enabled: true, output_style: "standard", module_type: "SecurityFiling"
      mnc.setup_json = [
        {model_field_uid: "sf_first_accepted_date"}
      ]
      mnc.save!
      mnc
    end
    
    it "sends ISF data" do
      # all we care about at this point is that generate_and_send_xml_document was called w/ the correct data, and when yielded
      # a value from nthat method, that an xref is created for it.
      mnc
      t = Time.zone.now
      cap = nil
      fake_data = double
      allow(fake_data).to receive(:event_code).and_return "code"
      allow(fake_data).to receive(:event_date).and_return t
      sync_record = SyncRecord.new
      allow(fake_data).to receive(:sync_record).and_return sync_record
      expect(sync_record).to receive(:save!)

      expect(subject).to receive(:generate_and_send_xml_document) { |cust_no, data, testing|
        expect(cust_no).to eq "cust"
        expect(testing).to be_falsey
        cap = data
      }.and_yield(fake_data)

      expect(Lock).to receive(:acquire).with("315-ref").and_yield

      subject.receive :save, isf
      # for this test, all we care about is that some data was sent (not what was in the data)
      expect(cap.length).to eq 1
    end


    it "sends if all search criterions pass" do
      mnc.search_criterions.create! model_field_uid: "sf_first_accepted_date", operator: "notnull"
      mnc.search_criterions.create! model_field_uid: "sf_first_accepted_date", operator: "notnull"

      # If this method is called, then receive has done its job
      expect(subject).to receive(:generate_and_send_315s)

      subject.receive :save, isf
    end

    it "does not send if any search criterion fails" do
      mnc.search_criterions.create! model_field_uid: "sf_first_accepted_date", operator: "notnull"
      mnc.search_criterions.create! model_field_uid: "sf_first_accepted_date", operator: "null"

      # If this method is called, then receive has done its job
      expect(subject).not_to receive(:generate_and_send_315s)

      subject.receive :save, isf
    end

    it "does not send if event date has not changed" do
      DataCrossReference.create_315_milestone! isf, "first_accepted_date", subject.xref_date_value(isf.first_accepted_date)

      # If this method is called, then receive has done its job
      expect(subject).not_to receive(:generate_and_send_315s)

      subject.receive :save, isf
    end
  end

  describe "generate_and_send_315s" do
    let(:isf) { SecurityFiling.create! host_system_file_number: "ref", importer_account_code: "cust", transaction_number: "trans",  transport_mode_code: "10", scac: "SCAC", vessel: "VES",
                                   voyage: "VOY", entry_port_code: "ENT", lading_port_code: "LAD", master_bill_of_lading: "M\nB", house_bills_of_lading: "H\nB", container_numbers: "C\nN", po_numbers: "P\nO", first_accepted_date: "2015-03-01 08:00"}
   
    it "generates and sends data" do
      t = Time.zone.now
      cap = nil
      fake_data = double
      allow(fake_data).to receive(:event_code).and_return "code"
      allow(fake_data).to receive(:event_date).and_return t
      sync_record = SyncRecord.new
      allow(fake_data).to receive(:sync_record).and_return sync_record
      expect(sync_record).to receive(:save!)
      expect(subject).to receive(:generate_and_send_xml_document) { |cust_no, data, testing|
        expect(cust_no).to eq "cust"
        expect(testing).to be_falsey
        cap = data
      }.and_yield(fake_data)

      subject.generate_and_send_315s "standard", isf, [OpenChain::CustomHandler::Isf315Generator::MilestoneUpdate.new("code", t.iso8601)], false

      # Verify the correct data was created (actual xml generation is purview of the generator support spec)
      d = cap.first
      expect(d.broker_reference).to eq "ref"
      expect(d.entry_number).to eq "trans"
      expect(d.ship_mode).to eq "10"
      expect(d.carrier_code).to eq "SCAC"
      expect(d.vessel).to eq "VES"
      expect(d.voyage_number).to eq "VOY"
      expect(d.port_of_entry).to eq "ENT"
      expect(d.port_of_lading).to eq "LAD"
      expect(d.master_bills).to eq ["M", "B"]
      expect(d.container_numbers).to eq ["C", "N"]
      expect(d.house_bills).to eq ["H", "B"]
      expect(d.po_numbers).to eq "P\nO"
      expect(d.event_code).to eq "code"
      expect(d.event_date).to eq t.iso8601
      expect(d.datasource).to eq "isf"
    end

    it "splits data by master bill" do
      cap = []
      expect(subject).to receive(:generate_and_send_xml_document) do |cust_no, data, testing|
        cap.push *data
      end
      subject.generate_and_send_315s MilestoneNotificationConfig::OUTPUT_STYLE_MBOL, isf, [OpenChain::CustomHandler::Isf315Generator::MilestoneUpdate.new("code", Time.zone.now)], false

      expect(cap.size).to eq 2
      expect(cap[0].master_bills).to eq ["M"]
      expect(cap[1].master_bills).to eq ["B"]
    end

    it "splits data by house bill" do
      cap = []
      expect(subject).to receive(:generate_and_send_xml_document) do |cust_no, data, testing|
        cap.push *data
      end
      subject.generate_and_send_315s MilestoneNotificationConfig::OUTPUT_STYLE_HBOL, isf, [OpenChain::CustomHandler::Isf315Generator::MilestoneUpdate.new("code", Time.zone.now)], false

      expect(cap.size).to eq 2
      expect(cap[0].house_bills).to eq ["H"]
      expect(cap[1].house_bills).to eq ["B"]
    end

    it "splits data by mbol container" do
      cap = []
      expect(subject).to receive(:generate_and_send_xml_document) do |cust_no, data, testing|
        cap.push *data
      end
      subject.generate_and_send_315s MilestoneNotificationConfig::OUTPUT_STYLE_MBOL_CONTAINER_SPLIT, isf, [OpenChain::CustomHandler::Isf315Generator::MilestoneUpdate.new("code", Time.zone.now)], false
 
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
      expect(subject).to receive(:generate_and_send_xml_document) do |cust_no, data, testing|
        cap.push *data
      end
      subject.generate_and_send_315s "standard", isf, [OpenChain::CustomHandler::Isf315Generator::MilestoneUpdate.new("code1", Time.zone.now), OpenChain::CustomHandler::Isf315Generator::MilestoneUpdate.new("code2", Time.zone.now)], false
      expect(cap.size).to eq 2
      expect(cap[0].event_code).to eq "code1"
      expect(cap[1].event_code).to eq "code2"
    end
  end
end 