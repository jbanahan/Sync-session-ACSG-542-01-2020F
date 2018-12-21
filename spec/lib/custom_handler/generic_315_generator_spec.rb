require 'spec_helper'

describe OpenChain::CustomHandler::Generic315Generator do

  describe "accepts?" do
    context "with custom feature enabled" do
      before :each do
        ms = double
        allow(MasterSetup).to receive(:get).and_return ms
        allow(ms).to receive(:custom_feature?).with("Entry 315").and_return true
      end

      it "accepts entries linked to customer numbers with 315 setups" do
        e = Entry.new broker_reference: "ref", customer_number: "cust"
        c = MilestoneNotificationConfig.new customer_number: "cust", enabled: true, output_style: "standard", module_type: "Entry"
        c.save! 

        expect(subject.accepts? :save, e).to be_truthy
      end

      it "doesn't accept entries without 315 setups" do
        e = Entry.new broker_reference: "ref", customer_number: "cust"
        expect(subject.accepts? :save, e).to be_falsey
      end

      it "doesn't accept entries without customer numbers" do 
        c = MilestoneNotificationConfig.create! enabled: true, output_style: "standard", module_type: "Entry"
        e = Entry.new broker_reference: "cust"
        expect(subject.accepts? :save, e).to be_falsey
      end

      it "doesn't find 315 setups for other modules" do
        e = Entry.new broker_reference: "ref", customer_number: "cust"
        c = MilestoneNotificationConfig.new customer_number: "cust", enabled: true, output_style: "standard", module_type: "SecurityFiling"
        c.save! 

        expect(subject.accepts? :save, e).to be_falsey
      end

      it "doesn't accept entries linked to 315 setups that are disabled" do
        e = Entry.new broker_reference: "ref", customer_number: "cust"
        c = MilestoneNotificationConfig.new customer_number: "cust", enabled: false, output_style: "standard", module_type: "Entry"
        c.save! 

        expect(subject.accepts? :save, e).to be_falsey
      end

      it "accepts if multiple configs are setup" do
        e = Entry.new broker_reference: "ref", customer_number: "cust"
        c = MilestoneNotificationConfig.new customer_number: "cust", enabled: true, output_style: "standard", testing: false, module_type: "Entry"
        c1 = MilestoneNotificationConfig.new customer_number: "cust", enabled: true, output_style: "standard", testing: true, module_type: "Entry"
        c.save! 
        c1.save!

        expect(subject.accepts? :save, e).to be_truthy
      end

      it "accepts if configs are all testing" do
        e = Entry.new broker_reference: "ref", customer_number: "cust"
        c = MilestoneNotificationConfig.new customer_number: "cust", enabled: true, output_style: "standard", testing: true, module_type: "Entry"
        c.save!

        expect(subject.accepts? :save, e).to be_truthy
      end
    end
    
    it "doesn't accept entries if 'Entry 315' custom feature isn't enabled" do
      e = Entry.new broker_reference: "ref", customer_number: "cust"
      c = MilestoneNotificationConfig.new customer_number: "cust", enabled: true, output_style: "standard", module_type: "Entry"
      c.save! 

      ms = double
      allow(MasterSetup).to receive(:get).and_return ms
      allow(ms).to receive(:custom_feature?).with("Entry 315").and_return false

      expect(subject.accepts? :save, e).to be_falsey
    end
  end

  describe "receive" do
    before :each do
      @config = MilestoneNotificationConfig.new customer_number: "cust", enabled: true, output_style: "standard", module_type: "Entry"
      @config.setup_json = [
        {model_field_uid: "ent_release_date"}
      ]
      @config.save!
      @entry = Factory(:entry, source_system: "Alliance", customer_number: "cust", broker_reference: "123", release_date: "2015-03-01 08:00", master_bills_of_lading: "A\nB", container_numbers: "E\nF", cargo_control_number: "CCN1\nCCN2")
    end

    it "generates and sends xml for 315 update" do
      expect(Lock).to receive(:acquire).with("315-123").and_yield 
      c = subject
      file_contents = nil
      ftp_opts = nil
      expect(c).to receive(:ftp_file) do |file, opts|
        file_contents = file.read
        ftp_opts = opts
      end
      c.receive :save, @entry

      # for this case, all we care about is that data was created with all masterbills / containers in a single doc
      # ..the full contents of the xml are tested in depth in the unit tests for the generate method.
      expect(file_contents).not_to be_nil
      r = REXML::Document.new(file_contents).root
      expect(REXML::XPath.each(r, "VfiTrack315/MasterBills/MasterBill").collect {|v| v.text}).to eq(["A", "B"])
      expect(REXML::XPath.each(r, "VfiTrack315/Containers/Container").collect {|v| v.text}).to eq(["E", "F"])

      @entry.reload
      expect(@entry.sync_records.size).to eq 1
      sr = @entry.sync_records.first
      expect(sr.sent_at).to be_within(1.minute).of Time.zone.now
      expect(sr.confirmed_at).to be_within(1.minute).of Time.zone.now
      expect(sr.trading_partner).to eq "315_release_date"
      expect(ftp_opts).to eq folder: "to_ecs/315/CUST"
    end

    it "generates and sends xml for 315 update for testing" do
      @config.testing = true
      @config.save!

      ftp_opts = nil
      expect(subject).to receive(:ftp_file) do |file, opts|
        ftp_opts = opts
      end
      subject.receive :save, @entry
      expect(ftp_opts).to eq folder: "to_ecs/315_test/CUST"
      # Testing setups don't store off sync records
      @entry.reload
      expect(@entry.sync_records.size).to eq 0
    end

    it "accepts if all search creatrions match" do
      @config.search_criterions.create! model_field_uid: "ent_release_date", operator: "notnull"
      c = subject
      expect(c).to receive(:ftp_file)
      c.receive :save, @entry
    end

    it "filters with search_criterions" do
      # Create one that matches and one that doesn't to ensure we bail even if only one doesn't match
      @config.search_criterions.create! model_field_uid: "ent_brok_ref", operator: "co", value: "NOMATCH"
      @config.search_criterions.create! model_field_uid: "ent_release_date", operator: "notnull"
      c = subject
      expect(c).not_to receive(:ftp_file)
      c.receive :save, @entry
    end

    it "does not send 315 if milestone date is same as previous send" do
      c = subject
      m = OpenChain::CustomHandler::Generic315Generator::MilestoneUpdate.new 'release_date', @entry.release_date.in_time_zone("Eastern Time (US & Canada)")
      fingerprint = c.calculate_315_fingerprint m, []
      @entry.sync_records.create! trading_partner: "315_release_date", fingerprint: fingerprint, sent_at: Time.zone.now, confirmed_at: Time.zone.now
      expect(c).not_to receive(:ftp_file)
      c.receive :save, @entry
    end

    it "converts to different timezone if instructed" do
      @config.setup_json = [
        {model_field_uid: "ent_release_date", timezone: "Hawaii"}
      ]
      @config.save!
      c = subject
      file_contents = nil
      expect(c).to receive(:ftp_file) do |file, opts|
        file_contents = file.read
      end

      c.receive :save, @entry
      r = REXML::Document.new(file_contents).root
      expect(r.text("VfiTrack315/Event/EventTime")).to eq(@entry.release_date.in_time_zone("Hawaii").strftime("%H%M"))
    end

    it "removes time" do
      @config.setup_json = [
        {model_field_uid: "ent_release_date", no_time: true}
      ]
      @config.save!
      c = subject
      file_contents = nil
      expect(c).to receive(:ftp_file) do |file, opts|
        file_contents = file.read
      end

      c.receive :save, @entry
      r = REXML::Document.new(file_contents).root
      expect(r.text("VfiTrack315/Event/EventTime")).to eq("0000")
    end

    it "removes the time after changing to different timezone" do
      # Use a time/timezone that will roll the date back a day to prove we're trimming the time after changing the tiezone
      @config.setup_json = [
        {model_field_uid: "ent_release_date", timezone: "Hawaii", no_time: true}
      ]
      @config.save!
      c = subject
      file_contents = nil
      expect(c).to receive(:ftp_file) do |file, opts|
        file_contents = file.read
      end

      c.receive :save, @entry
      r = REXML::Document.new(file_contents).root
      expect(r.text("VfiTrack315/Event/EventDate")).to eq((@entry.release_date - 1.day).to_date.strftime("%Y%m%d"))
    end

    it "sends distinct VfiTrack315 elements for each masterbill / container combination when output_format is 'mbol_container'" do
      @config.output_style = MilestoneNotificationConfig::OUTPUT_STYLE_MBOL_CONTAINER_SPLIT
      @config.save!

      c = subject
      file_contents = nil
      expect(c).to receive(:ftp_file).exactly(1).times do |file|
        file_contents = file.read
      end
      c.receive :save, @entry

      expect(file_contents).not_to be_nil
      r = REXML::Document.new(file_contents).root

      docs = REXML::XPath.each(r, "VfiTrack315").collect {|v| v }

      expect(docs.size).to eq 4

      expect(docs[0].text "MasterBills/MasterBill").to eq "A"
      expect(docs[0].text "Containers/Container").to eq "E"
      expect(docs[1].text "MasterBills/MasterBill").to eq "A"
      expect(docs[1].text "Containers/Container").to eq "F"
      expect(docs[2].text "MasterBills/MasterBill").to eq "B"
      expect(docs[2].text "Containers/Container").to eq "E"
      expect(docs[3].text "MasterBills/MasterBill").to eq "B"
      expect(docs[3].text "Containers/Container").to eq "F"
    end

    it "sends distinct VfiTrack315 elements for each masterbill when output_format is 'mbol'" do
      @config.output_style = MilestoneNotificationConfig::OUTPUT_STYLE_MBOL
      @config.save!

      c = subject
      file_contents = nil
      expect(c).to receive(:ftp_file).exactly(1).times do |file|
        file_contents = file.read
      end
      c.receive :save, @entry

      expect(file_contents).not_to be_nil
      r = REXML::Document.new(file_contents).root

      docs = REXML::XPath.each(r, "VfiTrack315").collect {|v| v }

      expect(docs.size).to eq 2
      expect(docs[0].text "MasterBills/MasterBill").to eq "A"
      expect(REXML::XPath.each(docs[0], "Containers/Container").collect {|v| v.text}).to eq(["E", "F"])
      expect(docs[1].text "MasterBills/MasterBill").to eq "B"
      expect(REXML::XPath.each(docs[1], "Containers/Container").collect {|v| v.text}).to eq(["E", "F"])
    end

    it "sends distinct VfiTrack315 elements for each ccn when output_format is 'ccn'" do
      @config.output_style = MilestoneNotificationConfig::OUTPUT_STYLE_CCN
      @config.save!

      c = subject
      file_contents = nil
      expect(c).to receive(:ftp_file).exactly(1).times do |file|
        file_contents = file.read
      end
      @entry.cargo_control_number
      c.receive :save, @entry

      expect(file_contents).not_to be_nil
      r = REXML::Document.new(file_contents).root

      docs = REXML::XPath.each(r, "VfiTrack315").collect {|v| v }

      expect(docs.size).to eq 2
      expect(docs[0].text "CargoControlNumber").to eq "CCN1"
      expect(docs[1].text "CargoControlNumber").to eq "CCN2"
    end

    it "sends milestones for each config that is enabled" do
      config2 = MilestoneNotificationConfig.new customer_number: "cust", enabled: true, output_style: "standard", testing: true, module_type: "Entry"
      config2.setup_json = [
        {model_field_uid: "ent_file_logged_date"}
      ]
      config2.save!

      @entry.update_attributes! file_logged_date: Time.zone.now

      file_contents = []
      expect(subject).to receive(:ftp_file).exactly(2).times do |file|
        file_contents << file.read
      end
      subject.receive :save, @entry

      expect(file_contents.size).to eq 2

      # The first file is going to be the first config..
      r = REXML::Document.new(file_contents.first).root
      expect(r.text "VfiTrack315/Event/EventCode").to eq "release_date"

      # The second should be the file logged testing config
      r = REXML::Document.new(file_contents.second).root
      expect(r.text "VfiTrack315/Event/EventCode").to eq "file_logged_date"

      # Testing configs should not set cross reference values
      expect(DataCrossReference.find_315_milestone @entry, 'file_logged_date').to be_nil
    end
  end

  describe "create_315_data" do
    let(:entry) {
      Entry.new(broker_reference: "REF", entry_number: "ENT", transport_mode_code: "10", fcl_lcl: "F", carrier_code: "CAR", 
        vessel: "VES", voyage: "VOY", entry_port_code: "1234", lading_port_code: "6543", po_numbers: "ABC\n DEF")
    }
    let(:milestone) { OpenChain::CustomHandler::Generator315Support::MilestoneUpdate.new('code', Time.zone.now.to_date, SyncRecord.new) }
    let(:canada) { Factory(:country, iso_code: 'CA')}

    it "extracts data from entry for 315 creation" do
      d = subject.send(:create_315_data, entry, {master_bills: ["ABC"], container_numbers: ["CON"], house_bills: ["HAWB"], cargo_control_numbers: ["CARGO", "CARGO2"]}, milestone)

      expect(d.broker_reference).to eq "REF"
      expect(d.entry_number).to eq "ENT"
      expect(d.ship_mode).to eq "10"
      expect(d.service_type).to eq "F"
      expect(d.carrier_code).to eq "CAR"
      expect(d.vessel).to eq "VES"
      expect(d.voyage_number).to eq "VOY"
      expect(d.port_of_entry).to eq "1234"
      expect(d.port_of_lading).to eq "6543"
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
      entry.assign_attributes import_country: canada, ca_entry_port: Port.new(cbsa_port: "1234", unlocode: "CACOD")
      d = subject.send(:create_315_data, entry, {}, milestone)

      expect(d.port_of_entry).to eq "CACOD"
    end

    it "raises an error if the Canadian Port does not have an associated UN Locode" do
      entry.assign_attributes import_country: canada, ca_entry_port: Port.new(cbsa_port: "1234")
      expect{subject.send(:create_315_data, entry, {}, milestone)}.to raise_error "Missing UN Locode for Canadian Port Code 1234."
    end

    it "doesn't raise error if Canadian Port is unset" do
      entry.assign_attributes import_country: canada
      d = subject.send(:create_315_data, entry, {}, milestone)
      expect(d.port_of_entry).to be_nil
    end
  end

end