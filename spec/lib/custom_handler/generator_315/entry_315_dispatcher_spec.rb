describe OpenChain::CustomHandler::Generator315::Entry315Dispatcher do

  def milestone_update code, date, sync_record = nil
    OpenChain::CustomHandler::Generator315::Shared315Support::MilestoneUpdate.new code, date, sync_record
  end

  let(:xml_generator) { OpenChain::CustomHandler::Generator315::Entry315XmlGenerator }

  describe "accepts?" do
    let (:ms) { stub_master_setup }
    let (:config) { MilestoneNotificationConfig.create! customer_number: "cust", enabled: true, output_style: "standard", module_type: "Entry"}

    context "with custom feature enabled" do
      before do
        allow(ms).to receive(:custom_feature?).with("Entry 315").and_return true
      end

      it "accepts entries linked to customer numbers with 315 setups" do
        ent = Entry.new broker_reference: "ref", customer_number: "cust"
        config

        expect(subject.accepts?(:save, ent)).to eq true
      end

      it "doesn't accept entries without 315 setups" do
        ent = Entry.new broker_reference: "ref", customer_number: "cust"
        expect(subject.accepts?(:save, ent)).to eq false
      end

      it "doesn't accept entries without customer numbers" do
        config
        ent = Entry.new broker_reference: "cust"
        expect(subject.accepts?(:save, ent)).to eq false
      end

      it "doesn't find 315 setups for other modules" do
        ent = Entry.new broker_reference: "ref", customer_number: "cust"
        config.update! module_type: "SecurityFiling"
        expect(subject.accepts?(:save, ent)).to eq false
      end

      it "doesn't accept entries linked to 315 setups that are disabled" do
        ent = Entry.new broker_reference: "ref", customer_number: "cust"
        config.update! enabled: false
        expect(subject.accepts?(:save, ent)).to eq false
      end

      it "accepts if multiple configs are setup" do
        ent = Entry.new broker_reference: "ref", customer_number: "cust"
        config
        MilestoneNotificationConfig.create! customer_number: "cust", enabled: true, output_style: "standard", testing: true, module_type: "Entry"
        expect(subject.accepts?(:save, ent)).to eq true
      end

      it "accepts if configs are all testing" do
        ent = Entry.new broker_reference: "ref", customer_number: "cust"
        config.update! testing: true
        expect(subject.accepts?(:save, ent)).to eq true
      end

      context "with linked importer company" do

        let (:importer) { create(:importer) }

        let (:parent) do
          imp = create(:importer, system_code: "PARENT")
          imp.linked_companies << importer
          imp
        end

        it "accepts if config is linked to parent system code" do
          config.update! customer_number: nil, parent_system_code: parent.system_code
          ent = Entry.new broker_reference: "ref", customer_number: "cust", importer: importer
          expect(subject.accepts?(:save, ent)).to eq true
        end

        it "does not accept if config does not match parent system code" do
          config.update! customer_number: nil, parent_system_code: "NOMATCH"
          ent = Entry.new broker_reference: "ref", customer_number: "cust", importer: importer
          expect(subject.accepts?(:save, ent)).to eq false
        end
      end

    end

    it "doesn't accept entries if 'Entry 315' custom feature isn't enabled" do
      ent = Entry.new broker_reference: "ref", customer_number: "cust"
      c = MilestoneNotificationConfig.new customer_number: "cust", enabled: true, output_style: "standard", module_type: "Entry"
      c.save!

      ms = double
      allow(MasterSetup).to receive(:get).and_return ms
      allow(ms).to receive(:custom_feature?).with("Entry 315").and_return false

      expect(subject.accepts?(:save, ent)).to eq false
    end
  end

  describe "receive" do
    let! (:config) do
      config = MilestoneNotificationConfig.new customer_number: "cust", enabled: true, output_style: "standard", module_type: "Entry"
      config.setup_json = [{model_field_uid: "ent_release_date"}]
      config.save!
      config
    end
    let! (:entry) do
      create(:entry, source_system: "Alliance", customer_number: "cust", broker_reference: "123", release_date: "2015-03-01 08:00",
                      master_bills_of_lading: "A\nB", container_numbers: "E\nF", cargo_control_number: "CCN1\nCCN2")
    end

    it "generates and sends xml for 315 update" do
      expect(Lock).to receive(:acquire).with("315-123").and_yield
      file_contents = nil
      ftp_opts = nil
      expect_any_instance_of(xml_generator).to receive(:ftp_file) do |_gen, file, opts|
        file_contents = file.read
        ftp_opts = opts
      end
      subject.receive :save, entry

      # for this case, all we care about is that data was created with all masterbills / containers in a single doc
      # ..the full contents of the xml are tested in depth in the unit tests for the generate method.
      expect(file_contents).not_to be_nil
      r = REXML::Document.new(file_contents).root
      expect(REXML::XPath.each(r, "VfiTrack315/MasterBills/MasterBill").collect(&:text)).to eq(["A", "B"])
      expect(REXML::XPath.each(r, "VfiTrack315/Containers/Container").collect(&:text)).to eq(["E", "F"])

      entry.reload
      expect(entry.sync_records.size).to eq 1
      sr = entry.sync_records.first
      expect(sr.sent_at).to be_within(1.minute).of Time.zone.now
      expect(sr.confirmed_at).to be_within(1.minute).of Time.zone.now
      expect(sr.trading_partner).to eq "315_release_date"
      expect(ftp_opts).to eq folder: "to_ecs/315/CUST"
    end

    it "generates and sends xml for 315 update for testing" do
      config.update! testing: true

      ftp_opts = nil
      expect_any_instance_of(xml_generator).to receive(:ftp_file) do |_gen, _file, opts|
        ftp_opts = opts
      end
      subject.receive :save, entry
      expect(ftp_opts).to eq folder: "to_ecs/315_test/CUST"
      # Testing setups don't store off sync records
      entry.reload
      expect(entry.sync_records.size).to eq 0
    end

    it "accepts if all search creatrions match" do
      config.search_criterions.create! model_field_uid: "ent_release_date", operator: "notnull"
      expect_any_instance_of(xml_generator).to receive(:ftp_file)
      subject.receive :save, entry
    end

    it "filters with search_criterions" do
      # Create one that matches and one that doesn't to ensure we bail even if only one doesn't match
      config.search_criterions.create! model_field_uid: "ent_brok_ref", operator: "co", value: "NOMATCH"
      config.search_criterions.create! model_field_uid: "ent_release_date", operator: "notnull"
      expect_any_instance_of(xml_generator).not_to receive(:ftp_file)
      subject.receive :save, entry
    end

    it "does not send 315 if milestone date is same as previous send" do
      m = milestone_update 'release_date', entry.release_date.in_time_zone("Eastern Time (US & Canada)")
      fingerprint = subject.calculate_315_fingerprint m, []
      entry.sync_records.create! trading_partner: "315_release_date", fingerprint: fingerprint, sent_at: Time.zone.now, confirmed_at: Time.zone.now
      expect_any_instance_of(xml_generator).not_to receive(:ftp_file)
      subject.receive :save, entry
    end

    it "converts to different timezone if instructed" do
      config.setup_json = [
        {model_field_uid: "ent_release_date", timezone: "Hawaii"}
      ]
      config.save!
      file_contents = nil
      expect_any_instance_of(xml_generator).to receive(:ftp_file) do |_gen, file, _opts|
        file_contents = file.read
      end

      subject.receive :save, entry
      r = REXML::Document.new(file_contents).root
      expect(r.text("VfiTrack315/Event/EventTime")).to eq(entry.release_date.in_time_zone("Hawaii").strftime("%H%M"))
    end

    it "removes time" do
      config.setup_json = [
        {model_field_uid: "ent_release_date", no_time: true}
      ]
      config.save!
      file_contents = nil
      expect_any_instance_of(xml_generator).to receive(:ftp_file) do |_gen, file, _opts|
        file_contents = file.read
      end

      subject.receive :save, entry
      r = REXML::Document.new(file_contents).root
      expect(r.text("VfiTrack315/Event/EventTime")).to eq("0000")
    end

    it "removes the time after changing to different timezone" do
      # Use a time/timezone that will roll the date back a day to prove we're trimming the time after changing the tiezone
      config.setup_json = [
        {model_field_uid: "ent_release_date", timezone: "Hawaii", no_time: true}
      ]
      config.save!
      file_contents = nil
      expect_any_instance_of(xml_generator).to receive(:ftp_file) do |_gen, file, _opts|
        file_contents = file.read
      end

      subject.receive :save, entry
      r = REXML::Document.new(file_contents).root
      expect(r.text("VfiTrack315/Event/EventDate")).to eq((entry.release_date - 1.day).to_date.strftime("%Y%m%d"))
    end

    it "sends distinct VfiTrack315 elements for each masterbill / container combination when output_format is 'mbol_container'" do
      config.update! output_style: MilestoneNotificationConfig::OUTPUT_STYLE_MBOL_CONTAINER_SPLIT

      file_contents = nil
      expect_any_instance_of(xml_generator).to receive(:ftp_file).once do |_gen, file|
        file_contents = file.read
      end
      subject.receive :save, entry

      expect(file_contents).not_to be_nil
      r = REXML::Document.new(file_contents).root

      docs = REXML::XPath.each(r, "VfiTrack315").collect {|v| v }

      expect(docs.size).to eq 4

      expect(docs[0].text("MasterBills/MasterBill")).to eq "A"
      expect(docs[0].text("Containers/Container")).to eq "E"
      expect(docs[1].text("MasterBills/MasterBill")).to eq "A"
      expect(docs[1].text("Containers/Container")).to eq "F"
      expect(docs[2].text("MasterBills/MasterBill")).to eq "B"
      expect(docs[2].text("Containers/Container")).to eq "E"
      expect(docs[3].text("MasterBills/MasterBill")).to eq "B"
      expect(docs[3].text("Containers/Container")).to eq "F"
    end

    it "sends distinct VfiTrack315 elements for each masterbill when output_format is 'mbol'" do
      config.update! output_style: MilestoneNotificationConfig::OUTPUT_STYLE_MBOL

      file_contents = nil
      expect_any_instance_of(xml_generator).to receive(:ftp_file).once do |_gen, file|
        file_contents = file.read
      end
      subject.receive :save, entry

      expect(file_contents).not_to be_nil
      r = REXML::Document.new(file_contents).root

      docs = REXML::XPath.each(r, "VfiTrack315").collect {|v| v }

      expect(docs.size).to eq 2
      expect(docs[0].text("MasterBills/MasterBill")).to eq "A"
      expect(REXML::XPath.each(docs[0], "Containers/Container").collect(&:text)).to eq(["E", "F"])
      expect(docs[1].text("MasterBills/MasterBill")).to eq "B"
      expect(REXML::XPath.each(docs[1], "Containers/Container").collect(&:text)).to eq(["E", "F"])
    end

    it "sends distinct VfiTrack315 elements for each ccn when output_format is 'ccn'" do
      config.update! output_style: MilestoneNotificationConfig::OUTPUT_STYLE_CCN

      file_contents = nil
      expect_any_instance_of(xml_generator).to receive(:ftp_file).once do |_gen, file|
        file_contents = file.read
      end
      entry.cargo_control_number
      subject.receive :save, entry

      expect(file_contents).not_to be_nil
      r = REXML::Document.new(file_contents).root

      docs = REXML::XPath.each(r, "VfiTrack315").collect {|v| v }

      expect(docs.size).to eq 2
      expect(docs[0].text("CargoControlNumber")).to eq "CCN1"
      expect(docs[1].text("CargoControlNumber")).to eq "CCN2"
    end

    it "sends milestones for each config that is enabled" do
      config2 = MilestoneNotificationConfig.new customer_number: "cust", enabled: true, output_style: "standard", testing: true, module_type: "Entry"
      config2.setup_json = [
        {model_field_uid: "ent_file_logged_date"}
      ]
      config2.save!

      entry.update! file_logged_date: Time.zone.now

      file_contents = []
      ftp_call_counter = 0
      allow_any_instance_of(xml_generator).to receive(:ftp_file) do |_gen, file|
        file_contents << file.read
        ftp_call_counter += 1
      end
      subject.receive :save, entry

      expect(ftp_call_counter).to eq 2
      expect(file_contents.size).to eq 2

      # The first file is going to be the first config..
      r = REXML::Document.new(file_contents.first).root
      expect(r.text("VfiTrack315/Event/EventCode")).to eq "release_date"

      # The second should be the file logged testing config
      r = REXML::Document.new(file_contents.second).root
      expect(r.text("VfiTrack315/Event/EventCode")).to eq "file_logged_date"

      # Testing configs should not set cross reference values
      expect(DataCrossReference.find_315_milestone(entry, 'file_logged_date')).to be_nil
    end
  end
end
