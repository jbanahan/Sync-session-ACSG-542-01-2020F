describe OpenChain::CustomHandler::Generator315::Abstract315XmlGenerator do
  subject do
    Class.new(OpenChain::CustomHandler::Generator315::Abstract315XmlGenerator) do
      def split_entry_data_identifiers _, _
        raise "Mock Me!"
      end

      def create_315_data _, _, _
        raise "Mock Me!"
      end
    end.new
  end

  let (:us) { create(:country, iso_code: "US")}
  let (:port_entry) { create(:port, schedule_d_code: "1234", name: "Entry Port", address: create(:full_address, country: us, line_2: "Line 2", line_3: "Line 3")) }
  let (:port_unlading) { create(:port, schedule_d_code: "9876", name: "Unlading Port", address: create(:full_address, country: us)) }
  let (:port_lading) { create(:port, schedule_k_code: "65433", name: "Lading Port", address: create(:full_address, country: us)) }

  let (:data) do
    data = described_class::Data315.new "ref", "ent", 10, "LCL", "SCAC", "ves", "voy", "1234", port_entry, "65433", port_lading, "9876",
                                        port_unlading, "CCN", "A\nB", "C\nD", "E\nF", "G\nH", "CUST", "release_date",
                                        ActiveSupport::TimeZone["America/New_York"].parse("201501011230")
    data.sync_record = SyncRecord.new
    data
  end

  describe "write_315_xml" do
    it "generates xml" do
      doc = REXML::Document.new("<root></root>")

      subject.write_315_xml doc.root, data
      r = doc.root.elements[1]

      expect(r.name).to eq "VfiTrack315"
      expect(r.text("BrokerReference")).to eq data.broker_reference
      expect(r.text("EntryNumber")).to eq data.entry_number
      expect(r.text("CustomerNumber")).to eq data.customer_number
      expect(r.text("ShipMode")).to eq data.ship_mode.to_s
      expect(r.text("ServiceType")).to eq data.service_type
      expect(r.text("CarrierCode")).to eq data.carrier_code
      expect(r.text("Vessel")).to eq data.vessel
      expect(r.text("VoyageNumber")).to eq data.voyage_number

      expect(r.text("PortOfEntry")).to eq data.port_of_entry
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfEntry']/LocationCode", "1234")
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfEntry']/LocationCodeType", "Schedule D")
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfEntry']/Name", "Entry Port")
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfEntry']/Address1", "99 Fake Street")
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfEntry']/Address2", "Line 2")
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfEntry']/Address3", "Line 3")
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfEntry']/City", "Fakesville")
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfEntry']/State", "PA")
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfEntry']/PostalCode", "19191")
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfEntry']/Country", "US")

      expect(r.text("PortOfLading")).to eq data.port_of_lading
      # We only have to check the few differing element values between the distinct ports
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfLading']/LocationCode", "65433")
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfLading']/LocationCodeType", "Schedule K")
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfLading']/Name", "Lading Port")
      # Just check the lines are nil, since they weren't set up
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfLading']/Address2", nil)
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfLading']/Address3", nil)

      expect(r.text("PortOfUnlading")).to eq data.port_of_unlading
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfUnlading']/LocationCode", "9876")
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfUnlading']/LocationCodeType", "Schedule D")
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfUnlading']/Name", "Unlading Port")

      expect(r.text("CargoControlNumber")).to eq data.cargo_control_number

      expect(REXML::XPath.each(r, "MasterBills/MasterBill").collect(&:text)).to eq(["A", "B"])
      expect(REXML::XPath.each(r, "HouseBills/HouseBill").collect(&:text)).to eq(["C", "D"])
      expect(REXML::XPath.each(r, "Containers/Container").collect(&:text)).to eq(["E", "F"])
      expect(REXML::XPath.each(r, "PoNumbers/PoNumber").collect(&:text)).to eq(["G", "H"])

      expect(r.text("Event/EventCode")).to eq "release_date"
      expect(r.text("Event/EventDate")).to eq "20150101"
      expect(r.text("Event/EventTime")).to eq "1230"
    end

    it "zeros event time if date object is given" do
      data.event_date = Date.new 2015, 1, 1
      doc = REXML::Document.new("<root></root>")
      subject.write_315_xml doc.root, data
      r = doc.root.elements[1]
      expect(r.text("Event/EventCode")).to eq "release_date"
      expect(r.text("Event/EventDate")).to eq "20150101"
      expect(r.text("Event/EventTime")).to eq "0000"
    end

    it "zero pads voyage number to at least 2 chars" do
      data.voyage_number = "1"
      doc = REXML::Document.new("<root></root>")
      subject.write_315_xml doc.root, data
      r = doc.root.elements[1]
      expect(r.text("VoyageNumber")).to eq "01"
    end

    it "detects unlocodes for LocationCodeType" do
      locode = create(:port, unlocode: "CNABC", name: "Chinese Port")
      data.port_of_lading = "CNABC"
      data.port_of_lading_location = locode

      doc = REXML::Document.new("<root></root>")

      subject.write_315_xml doc.root, data
      r = doc.root.elements[1]
      expect(r.text("PortOfLading")).to eq "CNABC"
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfLading']/LocationCode", "CNABC")
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfLading']/LocationCodeType", "UNLocode")
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfLading']/Name", "Chinese Port")
    end

    it "detects IATA codes for LocationCodeType" do
      locode = create(:port, iata_code: "YYZ", name: "Toronto Pearson Airport")
      data.port_of_lading = "YYZ"
      data.port_of_lading_location = locode

      doc = REXML::Document.new("<root></root>")

      subject.write_315_xml doc.root, data
      r = doc.root.elements[1]
      expect(r.text("PortOfLading")).to eq "YYZ"
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfLading']/LocationCode", "YYZ")
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfLading']/LocationCodeType", "IATA")
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfLading']/Name", "Toronto Pearson Airport")
    end

    it "detects CBSA codes for LocationCodeType" do
      locode = create(:port, cbsa_port: "9999", name: "Sarnia")
      data.port_of_lading = "9999"
      data.port_of_lading_location = locode

      doc = REXML::Document.new("<root></root>")

      subject.write_315_xml doc.root, data
      r = doc.root.elements[1]
      expect(r.text("PortOfLading")).to eq "9999"
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfLading']/LocationCode", "9999")
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfLading']/LocationCodeType", "CBSA")
      expect(r).to have_xpath_value("Location[LocationType = 'PortOfLading']/Name", "Sarnia")
    end
  end

  describe "generate_and_send_document" do

    it "creates xml document with elements for each 315 dataset, ftps it, and yields each 315 object sent" do
      d2 = data.clone
      # Simulate a split of masterbills (so we just verify two docs are generated.)
      d2.master_bills = "B"
      data.master_bills = "A"
      files = []
      folder = nil
      sync_records = []
      expect(subject).to receive(:ftp_sync_file) do |file, srs, opts|
        sync_records = srs
        files << file.read
        folder = opts[:folder]
      end

      milestones = []
      subject.generate_and_send_document("CN", [data, d2], false) do |ms|
        milestones << ms
      end
      expect(files.size).to eq 1
      root = REXML::Document.new(files.first).root
      expect(root.name).to eq "VfiTrack315s"
      expect(REXML::XPath.each(root, "VfiTrack315").size).to eq 2
      expect(root.children[0].text("MasterBills/MasterBill")).to eq "A"
      expect(root.children[1].text("MasterBills/MasterBill")).to eq "B"
      expect(milestones).to eq [data, d2]
      expect(folder).to eq "to_ecs/315/CN"

      expect(sync_records.length).to eq 2
      expect(sync_records.first).to be data.sync_record
    end

    it "creates xml document, ftps it, but doesn't yield when testing" do
      files = []
      folder = nil
      expect(subject).to receive(:ftp_sync_file) do |file, _srs, opts|
        files << file.read
        folder = opts[:folder]
      end
      milestones = []
      subject.generate_and_send_document("CN", data, true) do |ms|
        milestones << ms
      end
      expect(files.size).to eq 1
      expect(milestones).to be_blank
      expect(folder).to eq "to_ecs/315_test/CN"
    end
  end

  describe "generate_and_send_315s" do

    let (:config) { MilestoneNotificationConfig.new output_style: MilestoneNotificationConfig::OUTPUT_STYLE_STANDARD, customer_number: "config_cust" }

    it "splits data, generates milestones for each and sends" do
      splits = ["S1", "S2"]
      milestones = ["M1", "M2"]
      data_315s = ["D1", "D2", "D3", "D4"]
      obj = Object.new

      expect(subject).to receive(:split_entry_data_identifiers).with("standard", obj).and_return splits
      expect(subject).to receive(:create_315_data).with(obj, "S1", "M1").and_return data_315s[0]
      expect(subject).to receive(:create_315_data).with(obj, "S1", "M2").and_return data_315s[1]
      expect(subject).to receive(:create_315_data).with(obj, "S2", "M1").and_return data_315s[2]
      expect(subject).to receive(:create_315_data).with(obj, "S2", "M2").and_return data_315s[3]
      expect(subject).to receive(:setup_customer).with(config).and_return "setup_customer"

      expect(subject).to receive(:generate_and_send_document).with("setup_customer", data_315s, false).and_yield(data)
      expect(data.sync_record).to receive(:save!)
      now = time_now
      Timecop.freeze(now) do
        subject.generate_and_send_315s config, obj, milestones
        expect(data.sync_record.confirmed_at).to eq now
      end
    end
  end
end
