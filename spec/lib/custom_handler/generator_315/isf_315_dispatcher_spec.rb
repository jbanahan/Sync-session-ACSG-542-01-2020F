describe OpenChain::CustomHandler::Generator315::Isf315Dispatcher do

  def milestone_update code, date, sync_record = nil
    OpenChain::CustomHandler::Generator315::Shared315Support::MilestoneUpdate.new code, date, sync_record
  end

  let(:xml_generator) { OpenChain::CustomHandler::Generator315::Isf315XmlGenerator }

  describe "accepts?" do

    let(:isf) { SecurityFiling.new host_system_file_number: "ref", importer_account_code: "cust" }
    let(:mnc) { MilestoneNotificationConfig.new customer_number: "cust", enabled: true, output_style: "standard", module_type: "SecurityFiling" }

    context "with 'ISF 315' custom feature" do
      before do
        ms = stub_master_setup
        allow(ms).to receive(:custom_feature?).with("ISF 315").and_return true
      end

      it "does not isf with missing importer account code" do
        isf.importer_account_code = ""
        mnc.save!

        expect(subject.accepts?(:save, isf)).to be_falsey
      end

      it "accepts isf with all standard info" do
        mnc.save!
        expect(subject.accepts?(:save, isf)).to be_truthy
      end

      it "does not accept isf with no setups linked to customer account" do
        mnc.save!
        isf.importer_account_code = "ABC"
        expect(subject.accepts?(:save, isf)).to be_falsey
      end

      it "does not accept isf with disabled setup" do
        mnc.enabled = false
        mnc.save!

        expect(subject.accepts?(:save, isf)).to be_falsey
      end

      context "with linked importer company" do

        let (:importer) { create(:importer) }

        let (:parent) do
          imp = create(:importer, system_code: "PARENT")
          imp.linked_companies << importer
          imp
        end

        it "accepts if config is linked to parent system code" do
          mnc.update! customer_number: nil, parent_system_code: parent.system_code
          isf.importer = importer
          isf.save!
          expect(subject.accepts?(:save, isf)).to eq true
        end

        it "does not accept if config does not match parent system code" do
          mnc.update! customer_number: nil, parent_system_code: "NOMATCH"
          isf.importer = importer
          isf.save!
          expect(subject.accepts?(:save, isf)).to eq false
        end
      end
    end

    it "does not accept isfs if 'ISF 315' custom feature is disabled" do
      mnc.save!
      expect(subject.accepts?(:save, isf)).to be_falsey
    end
  end

  describe "receive" do
    let(:isf) do
      create(:security_filing, host_system_file_number: "ref", importer_account_code: "cust", transaction_number: "trans",  transport_mode_code: "10",
                                scac: "SCAC", vessel: "VES", voyage: "VOY", entry_port_code: "ENT", lading_port_code: "LAD", master_bill_of_lading: "M\nB",
                                house_bills_of_lading: "H\nB", container_numbers: "C\nN", po_numbers: "P\nO", first_accepted_date: "2015-03-01 08:00")
    end
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

      expect_any_instance_of(xml_generator).to receive(:generate_and_send_document) { |_gen, cust_no, data, testing|
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
      expect_any_instance_of(xml_generator).to receive(:generate_and_send_315s)

      subject.receive :save, isf
    end

    it "does not send if any search criterion fails" do
      mnc.search_criterions.create! model_field_uid: "sf_first_accepted_date", operator: "notnull"
      mnc.search_criterions.create! model_field_uid: "sf_first_accepted_date", operator: "null"

      # If this method is called, then receive has done its job
      expect_any_instance_of(xml_generator).not_to receive(:generate_and_send_315s)

      subject.receive :save, isf
    end

    it "does not send if event date has not changed" do
      DataCrossReference.create_315_milestone! isf, "first_accepted_date", subject.xref_date_value(isf.first_accepted_date)

      # If this method is called, then receive has done its job
      expect_any_instance_of(xml_generator).not_to receive(:generate_and_send_315s)

      subject.receive :save, isf
    end
  end

end
