require 'spec_helper'

describe OpenChain::CustomHandler::Generator315Support do
  subject do 
    Class.new do 
      include OpenChain::CustomHandler::Generator315Support
    end.new
  end

  before :each do 
    @data = OpenChain::CustomHandler::Generator315Support::Data315.new "ref", "ent", 10, "LCL", "SCAC", "ves", "voy", "e_p", "l_p", "CCN", "A\nB", "C\nD", "E\nF", "G\nH", "release_date", ActiveSupport::TimeZone["America/New_York"].parse("201501011230")
  end

  describe "write_315_xml" do
    it "generates xml" do
      dt = Time.zone.parse "2015-01-01 12:30"
      doc = REXML::Document.new("<root></root>")

      subject.write_315_xml doc.root, "CN", @data
      r = doc.root.elements[1]

      expect(r.name).to eq "VfiTrack315"
      expect(r.text "BrokerReference").to eq @data.broker_reference
      expect(r.text "EntryNumber").to eq @data.entry_number
      expect(r.text "CustomerNumber").to eq "CN"
      expect(r.text "ShipMode").to eq @data.ship_mode.to_s
      expect(r.text "ServiceType").to eq @data.service_type
      expect(r.text "CarrierCode").to eq @data.carrier_code
      expect(r.text "Vessel").to eq @data.vessel
      expect(r.text "VoyageNumber").to eq @data.voyage_number
      expect(r.text "PortOfEntry").to eq @data.port_of_entry
      expect(r.text "PortOfLading").to eq @data.port_of_lading
      expect(r.text "CargoControlNumber").to eq @data.cargo_control_number

      expect(REXML::XPath.each(r, "MasterBills/MasterBill").collect {|v| v.text}).to eq(["A", "B"])
      expect(REXML::XPath.each(r, "HouseBills/HouseBill").collect {|v| v.text}).to eq(["C", "D"])
      expect(REXML::XPath.each(r, "Containers/Container").collect {|v| v.text}).to eq(["E", "F"])
      expect(REXML::XPath.each(r, "PoNumbers/PoNumber").collect {|v| v.text}).to eq(["G", "H"])

      expect(r.text "Event/EventCode").to eq "release_date"
      expect(r.text "Event/EventDate").to eq "20150101"
      expect(r.text "Event/EventTime").to eq "1230"
    end

    it "zeros event time if date object is given" do
      @data.event_date = Date.new 2015, 1, 1
      doc = REXML::Document.new("<root></root>")
      subject.write_315_xml doc.root, "CN", @data
      r = doc.root.elements[1]
      expect(r.text "Event/EventCode").to eq "release_date"
      expect(r.text "Event/EventDate").to eq "20150101"
      expect(r.text "Event/EventTime").to eq "0000"
    end
  end

  describe "generate_and_send_xml_document" do

    it "creates xml document with elements for each 315 dataset, ftps it, and yields each 315 object sent" do
      d2 = @data.clone
      # Simulate a split of masterbills (so we just verify two docs are generated.)
      d2.master_bills = "B"
      @data.master_bills = "A"
      files = []
      folder = nil
      subject.should_receive(:ftp_file) do |file, opts|
        files << file.read
        folder = opts[:folder]
      end

      milestones = []
      subject.generate_and_send_xml_document("CN", [@data, d2], false) do |ms|
        milestones << ms
      end
      expect(files.size).to eq 1
      root = REXML::Document.new(files.first).root
      expect(root.name).to eq "VfiTrack315s"
      expect(REXML::XPath.each(root, "VfiTrack315").size).to eq 2
      expect(root.children[0].text "MasterBills/MasterBill").to eq "A"
      expect(root.children[1].text "MasterBills/MasterBill").to eq "B"
      expect(milestones).to eq [@data, d2]
      expect(folder).to eq "to_ecs/315/CN"
    end

    it "creates xml document, ftps it, but doesn't yield when testing" do
      files = []
      folder = nil
      subject.should_receive(:ftp_file) do |file, opts|
        files << file.read
        folder = opts[:folder]
      end
      milestones = []
      subject.generate_and_send_xml_document("CN", @data, true) do |ms|
        milestones << ms
      end
      expect(files.size).to eq 1
      expect(milestones).to be_blank
      expect(folder).to eq "to_ecs/315_test/CN"
    end
  end

  describe "process_field" do
    let (:entry) { Factory(:entry, release_date: Time.zone.parse("2015-12-01 12:05")) }
    let (:user) { Factory(:master_user) }
    let (:field) {
      {
        model_field_uid: :ent_release_date
      }
    }

    it "returns a milestone update object for a specific model field" do
      milestone = subject.process_field field, user, entry, false, []
      expect(milestone.code).to eq "release_date"
      expect(milestone.date).to eq entry.release_date.in_time_zone("America/New_York")
      expect(milestone.sync_record.sent_at).to be_within(1.minutes).of(Time.zone.now)
      expect(milestone.sync_record.fingerprint).not_to be_nil
      expect(milestone.sync_record.trading_partner).to eq "315_release_date"
    end

    it "returns a milestone update object when a sync_record has been cleared" do
      sr = entry.sync_records.create! trading_partner: "315_release_date"

      milestone = subject.process_field field, user, entry, false, []
      expect(milestone.code).to eq "release_date"
      expect(milestone.sync_record).to eq sr
    end

  end
end