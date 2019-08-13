describe OpenChain::CustomHandler::Generator315Support do
  subject do 
    Class.new do 
      include OpenChain::CustomHandler::Generator315Support
    end.new
  end

  before :each do 
    @data = OpenChain::CustomHandler::Generator315Support::Data315.new "ref", "ent", 10, "LCL", "SCAC", "ves", "voy", "e_p", "l_p", "CCN", "A\nB", "C\nD", "E\nF", "G\nH", "release_date", ActiveSupport::TimeZone["America/New_York"].parse("201501011230")
    @data.sync_record = SyncRecord.new
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

    it "zero pads voyage number to at least 2 chars" do
      @data.voyage_number = "1"
      doc = REXML::Document.new("<root></root>")
      subject.write_315_xml doc.root, "CN", @data
      r = doc.root.elements[1]
      expect(r.text "VoyageNumber").to eq "01"
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
      sync_records = []
      expect(subject).to receive(:ftp_sync_file) do |file, srs, opts|
        sync_records = srs
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

      expect(sync_records.length).to eq 2
      expect(sync_records.first).to be @data.sync_record
    end

    it "creates xml document, ftps it, but doesn't yield when testing" do
      files = []
      folder = nil
      expect(subject).to receive(:ftp_sync_file) do |file, srs, opts|
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
      milestone = subject.process_field field, user, entry, false, false, []
      expect(milestone.code).to eq "release_date"
      expect(milestone.date).to eq entry.release_date.in_time_zone("America/New_York")
      expect(milestone.sync_record.sent_at).to be_within(1.minutes).of(Time.zone.now)
      expect(milestone.sync_record.fingerprint).not_to be_nil
      expect(milestone.sync_record.trading_partner).to eq "315_release_date"
      expect(milestone.sync_record.context).to be_empty
    end

    it "returns a milestone update object when a sync_record has been cleared" do
      sr = entry.sync_records.create! trading_partner: "315_release_date"

      milestone = subject.process_field field, user, entry, false, false, []
      expect(milestone.code).to eq "release_date"
      expect(milestone.sync_record).to eq sr
    end

    context "with gtn_time_modifier" do
      it "adds time to sync_record context even when no adjustment is needed" do
        milestone = subject.process_field field, user, entry, false, true, []
        expect(milestone.date).to eq entry.release_date.in_time_zone("America/New_York")
        expect(milestone.sync_record.context).to eq({"milestone_uids" => {"20151201" => [425]}})
      end

      it "increments timestamp by 1 if current one has already been used" do
        entry.sync_records.create! trading_partner: "315_release_date", context: {"milestone_uids" => {"20151201" => [425]}}.to_json
        milestone = subject.process_field field, user, entry, false, true, []
        expect(milestone.date).to eq entry.release_date.in_time_zone("America/New_York") + 1.minute
        uids = (milestone.sync_record.context)["milestone_uids"]["20151201"]
        expect(uids.count).to eq 2
        expect(uids[1]).to eq 426
      end

      it "decrements timestamp by 1 if current one and next one have already been used" do
        entry.sync_records.create! trading_partner: "315_release_date", context: {"milestone_uids" => {"20151201" => [425, 426]}}.to_json
        milestone = subject.process_field field, user, entry, false, true, []
        expect(milestone.date).to eq entry.release_date.in_time_zone("America/New_York") - 1.minute
        uids = (milestone.sync_record.context)["milestone_uids"]["20151201"]
        expect(uids.count).to eq 3
        expect(uids[2]).to eq 424
      end

      it "increments timestamp by 2 if current and immediately neighboring have already been used" do
        entry.sync_records.create! trading_partner: "315_release_date", context: {"milestone_uids" => {"20151201" => [425, 426, 424]}}.to_json
        milestone = subject.process_field field, user, entry, false, true, []
        expect(milestone.date).to eq entry.release_date.in_time_zone("America/New_York") + 2.minutes
        uids = (milestone.sync_record.context)["milestone_uids"]["20151201"]
        expect(uids.count).to eq 4
        expect(uids[3]).to eq 427
      end

      it "decrements timestamp by 2 if current immediate neighbors, and next highest have already been used" do
        entry.sync_records.create! trading_partner: "315_release_date", context: {"milestone_uids" => {"20151201" => [425, 426, 424, 427]}}.to_json
        milestone = subject.process_field field, user, entry, false, true, []
        expect(milestone.date).to eq entry.release_date.in_time_zone("America/New_York") - 2.minutes
        uids = (milestone.sync_record.context)["milestone_uids"]["20151201"]
        expect(uids.count).to eq 5
        expect(uids[4]).to eq 423
      end

      it "decrements timestamp if incrementing would change the day" do
        entry.update! release_date: Time.find_zone("Eastern Time (US & Canada)").parse("2015-12-01 23:59")
        entry.sync_records.create! trading_partner: "315_release_date", context: {"milestone_uids" => {"20151201" => [1439]}}.to_json
        milestone = subject.process_field field, user, entry, false, true, []
        expect(milestone.date).to eq entry.release_date.in_time_zone("America/New_York") - 1.minute
        uids = (milestone.sync_record.context)["milestone_uids"]["20151201"]
        expect(uids.count).to eq 2
        expect(uids[1]).to eq 1438
      end

      it "increments timestamp if decrementing would change the day" do
        entry.update! release_date: Time.find_zone("Eastern Time (US & Canada)").parse("2015-12-01 00:00")
        # Since increments are always attempted before decrements, setup requires that first increment already exists on the sync record.
        # We're checking that a second one gets made.
        entry.sync_records.create! trading_partner: "315_release_date", context: {"milestone_uids" => {"20151201" => [0, 1]}}.to_json
        milestone = subject.process_field field, user, entry, false, true, []
        expect(milestone.date).to eq entry.release_date.in_time_zone("America/New_York") + 2.minutes
        uids = (milestone.sync_record.context)["milestone_uids"]["20151201"]
        expect(uids.count).to eq 3
        expect(uids[2]).to eq 2
      end

      it "adds unmodified time if date has been sent 1440 times" do
        entry.sync_records.create! trading_partner: "315_release_date", context: {"milestone_uids" => {"20151201" => (0..1439).to_a}}.to_json
        milestone = subject.process_field field, user, entry, false, true, []
        expect(milestone.date).to eq entry.release_date.in_time_zone("America/New_York")
        uids = (milestone.sync_record.context)["milestone_uids"]["20151201"]
        expect(uids[1440]).to eq 425
      end

      it "works with regular dates" do
        field.merge! no_time: true
        
        milestone = subject.process_field field, user, entry, false, true, []
        expect(milestone.date).to eq subject.default_timezone.local(2015,12,01,0,0)
        expect(milestone.sync_record.context).to eq({"milestone_uids" => {"20151201" => [0]}})

        milestone2 = subject.process_field field, user, entry, false, true, []
        expect(milestone2.date).to eq subject.default_timezone.local(2015,12,01,0,1)
        expect(milestone2.sync_record.context).to eq({"milestone_uids" => {"20151201" => [0, 1]}})
      end

      context "sync records" do
        let(:sr) { SyncRecord.new  }
        
        describe "milestone_uids" do
          it "returns uids" do
            sr = SyncRecord.new trading_partner: "ACME", context: {"milestone_uids" => {"20190315" => [1,2]}}.to_json
            expect(subject.milestone_uids sr, "20190315").to eq [1,2]
            expect(subject.milestone_uids sr, "20190316").to be_empty
          end
        end

        describe "set_milestone_uids" do
          it "assigns uid" do
            sr = SyncRecord.new trading_partner: "ACME", context: nil
            subject.set_milestone_uids sr, "20190315", [1,2]
            expect(sr.context).to eq({"milestone_uids" => {"20190315" => [1,2]}})

            subject.set_milestone_uids sr, "20190315", [1,2,3]
            expect(sr.context).to eq({"milestone_uids" => {"20190315" => [1,2,3]}})

            subject.set_milestone_uids sr, "20190316", [4]
            expect(sr.context).to eq({"milestone_uids" => {"20190315" => [1,2,3], "20190316" => [4]}})
          end
        end
      end
    end
  end
end
