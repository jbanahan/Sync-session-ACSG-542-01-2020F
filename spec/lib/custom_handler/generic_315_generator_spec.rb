require 'spec_helper'

describe OpenChain::CustomHandler::Generic315Generator do

  describe "accepts?" do
    before :each do
      ms = double
      MasterSetup.stub(:get).and_return ms
      ms.stub(:system_code).and_return "www-vfitrack-net"
    end

    it "accepts entries linked to customer numbers with 315 setups" do
      e = Entry.new broker_reference: "ref", customer_number: "cust"
      c = MilestoneNotificationConfig.new customer_number: "cust", enabled: true, output_style: ""
      c.save! 

      expect(described_class.new.accepts? :save, e).to be_true
    end

    it "doesn't accept entries without 315 setups" do
      e = Entry.new broker_reference: "ref", customer_number: "cust"
      expect(described_class.new.accepts? :save, e).to be_false
    end

    it "doesn't accept entries without customer numbers" do 
      c = MilestoneNotificationConfig.create! enabled: true, output_style: ""
      e = Entry.new broker_reference: "cust"
      expect(described_class.new.accepts? :save, e).to be_false
    end

    it "doesn't accept entries linked to 315 setups that are disabled" do
      e = Entry.new broker_reference: "ref", customer_number: "cust"
      c = MilestoneNotificationConfig.new customer_number: "cust", enabled: false, output_style: ""
      c.save! 

      expect(described_class.new.accepts? :save, e).to be_false
    end
  end

  describe "receive" do
    before :each do
      @config = MilestoneNotificationConfig.new customer_number: "cust", enabled: true, output_style: ""
      @config.setup_json = [
        {model_field_uid: "ent_release_date"}
      ]
      @config.save!
      @entry = Factory(:entry, source_system: "Alliance", customer_number: "cust", release_date: "2015-03-01 08:00", master_bills_of_lading: "A\nB", container_numbers: "E\nF")
    end

    it "generates and sends xml for 315 update" do
      c = described_class.new
      file_contents = nil
      c.should_receive(:ftp_file) do |file|
        file_contents = file.read
      end
      c.receive :save, @entry

      # for this case, all we care about is that data was created..the contents of the xml
      # are tested in depth in the unit tests for the generate method.
      expect(file_contents).not_to be_nil
      # Make sure we saved off the actual date that was sent in the xml so we don't bother resending
      # the same data at a later time.
      expect(DataCrossReference.find_315_milestone @entry, 'release_date').to eq @entry.release_date.iso8601
    end

    it "accepts if all search creatrions match" do
      @config.search_criterions.create! model_field_uid: "ent_release_date", operator: "notnull"
      c = described_class.new
      c.should_receive(:ftp_file)
      c.receive :save, @entry
    end

    it "filters with search_criterions" do
      # Create one that matches and one that doesn't to ensure we bail even if only one doesn't match
      @config.search_criterions.create! model_field_uid: "ent_brok_ref", operator: "co", value: "NOMATCH"
      @config.search_criterions.create! model_field_uid: "ent_release_date", operator: "notnull"
      c = described_class.new
      c.should_not_receive(:ftp_file)
      c.receive :save, @entry
    end

    it "does not send 315 if milestone date is same as previous send" do
      DataCrossReference.create_315_milestone! @entry, 'release_date', @entry.release_date.iso8601
      c = described_class.new
      c.should_not_receive(:ftp_file)
      c.receive :save, @entry
    end

    it "converts to different timezone if instructed" do
      @config.setup_json = [
        {model_field_uid: "ent_release_date", timezone: "Eastern Time (US & Canada)"}
      ]
      @config.save!
      c = described_class.new
      c.should_receive(:ftp_file)

      c.receive :save, @entry

      expect(DataCrossReference.find_315_milestone @entry, 'release_date').to eq @entry.release_date.in_time_zone("Eastern Time (US & Canada)").iso8601
    end

    it "removes time" do
      @config.setup_json = [
        {model_field_uid: "ent_release_date", no_time: true}
      ]
      @config.save!
      c = described_class.new
      c.should_receive(:ftp_file)

      c.receive :save, @entry

      expect(DataCrossReference.find_315_milestone @entry, 'release_date').to eq @entry.release_date.to_date.iso8601
    end

    it "removes the time after changing to different timezone" do
      # Use a time/timezone that will roll the date back a day to prove we're trimming the time after changing the tiezone
      @config.setup_json = [
        {model_field_uid: "ent_release_date", timezone: "Hawaii", no_time: true}
      ]
      @config.save!
      c = described_class.new
      c.should_receive(:ftp_file)

      c.receive :save, @entry

      expect(DataCrossReference.find_315_milestone @entry, 'release_date').to eq (@entry.release_date - 1.day).to_date.iso8601
    end

    it "sends distinct 315 files for each masterbill / container combination when output_format is 'mbol_container'" do
      @config.output_style = MilestoneNotificationConfig::OUTPUT_STYLE_MBOL_CONTAINER_SPLIT
      @config.save!

      c = described_class.new
      file_contents = []
      c.should_receive(:ftp_file).exactly(4).times do |file|
        file_contents << file.read
      end
      c.receive :save, @entry

      expect(file_contents.size).to eq 4
      expect(REXML::Document.new(file_contents[0]).root.text "MasterBills/MasterBill").to eq "A"
      expect(REXML::Document.new(file_contents[0]).root.text "Containers/Container").to eq "E"
      expect(REXML::Document.new(file_contents[1]).root.text "MasterBills/MasterBill").to eq "A"
      expect(REXML::Document.new(file_contents[1]).root.text "Containers/Container").to eq "F"
      expect(REXML::Document.new(file_contents[2]).root.text "MasterBills/MasterBill").to eq "B"
      expect(REXML::Document.new(file_contents[2]).root.text "Containers/Container").to eq "E"
      expect(REXML::Document.new(file_contents[3]).root.text "MasterBills/MasterBill").to eq "B"
      expect(REXML::Document.new(file_contents[3]).root.text "Containers/Container").to eq "F"
    end
  end

  describe "generate" do
    before :each do 
      @e = Entry.new broker_reference: "ref", entry_number: "ent", customer_number: "cust", transport_mode_code: 10, fcl_lcl: "LCL", carrier_code: "SCAC",
            vessel: "ves", voyage: "voy", entry_port_code: "e_p", lading_port_code: "l_p", master_bills_of_lading: "A\nB", house_bills_of_lading: "C\nD", container_numbers: "E\nF",
            po_numbers: "G\nH"
    end

    it "generates xml" do
      dt = Time.zone.parse "2015-01-01 12:30"
      xml = described_class.new.generate @e, 'release_date', dt, @e.master_bills_of_lading.split(/\n/), @e.container_numbers.split(/\n/)
      r = xml.root

      expect(r.name).to eq "VfiTrack315"
      expect(r.text "BrokerReference").to eq @e.broker_reference
      expect(r.text "EntryNumber").to eq @e.entry_number
      expect(r.text "CustomerNumber").to eq @e.customer_number
      expect(r.text "ShipMode").to eq @e.transport_mode_code.to_s
      expect(r.text "ServiceType").to eq @e.fcl_lcl
      expect(r.text "CarrierCode").to eq @e.carrier_code
      expect(r.text "Vessel").to eq @e.vessel
      expect(r.text "VoyageNumber").to eq @e.voyage
      expect(r.text "PortOfEntry").to eq @e.entry_port_code
      expect(r.text "PortOfLading").to eq @e.lading_port_code

      expect(REXML::XPath.each(r, "MasterBills/MasterBill").collect {|v| v.text}).to eq(["A", "B"])
      expect(REXML::XPath.each(r, "HouseBills/HouseBill").collect {|v| v.text}).to eq(["C", "D"])
      expect(REXML::XPath.each(r, "Containers/Container").collect {|v| v.text}).to eq(["E", "F"])
      expect(REXML::XPath.each(r, "PoNumbers/PoNumber").collect {|v| v.text}).to eq(["G", "H"])

      expect(r.text "Event/EventCode").to eq "release_date"
      expect(r.text "Event/EventDate").to eq "20150101"
      expect(r.text "Event/EventTime").to eq "1230"
    end

    it "zeros event time if date object is given" do
      d = Date.new 2015, 1, 1
      xml = described_class.new.generate @e, 'release_date', d, [], []
      r = xml.root
      expect(r.text "Event/EventCode").to eq "release_date"
      expect(r.text "Event/EventDate").to eq "20150101"
      expect(r.text "Event/EventTime").to eq "0000"
    end
  end
end