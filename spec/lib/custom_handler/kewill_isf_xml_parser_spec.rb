describe OpenChain::CustomHandler::KewillIsfXmlParser do

  let (:xml_path) { 'spec/support/bin/isf_sample.xml' }
  let (:xml_data) { IO.read xml_path }
  let (:est) { ActiveSupport::TimeZone["Eastern Time (US & Canada)"] }
  let! (:customer) {
    c = create(:company, :alliance_customer_number=>'EDDIE')
    c.system_identifiers.create! system: "Customs Management", code: "EDDIE"
    c
  }

  let (:log) { InboundFile.new }

  describe "parse_file" do
    subject { described_class }

    it 'should process from text' do
      expect_any_instance_of(SecurityFiling).to receive(:broadcast_event).with(:save)
      subject.parse_file xml_data, log, bucket: "bucket", key: "key"
      sf = SecurityFiling.first
      expect(sf.host_system_file_number).to eq('1870446')
      expect(sf.host_system).to eq("Kewill")
      expect(sf.last_event.to_i).to eq(Time.iso8601("2012-11-27T09:20:01.565-05:00").to_i)
      # validate the time_to_process was recorded (use 10
      # to try to make sure we're recording milliseconds and not seconds)
      expect(sf.time_to_process).to be > 10
      expect(sf.time_to_process).to be < 1000 # NOTE: this fails if you're ever debugging the parser
      expect(sf.entity_snapshots.length).to eq 1
      s = sf.entity_snapshots.first
      expect(s.user).to eq User.integration
      expect(s.context).to eq "key"

      expect(log.company).to eq customer
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_ISF_NUMBER)[0].value).to eq "1870446"
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_ISF_NUMBER)[0].module_type).to eq "SecurityFiling"
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_ISF_NUMBER)[0].module_id).to eq sf.id
    end
    it "should not replace entry numbers" do
      sf = create(:security_filing, :entry_numbers=>"123456", :host_system=>'Kewill', :host_system_file_number=>'1870446', :last_event=>Time.zone.now)
      subject.parse_file xml_data, log
      sf = SecurityFiling.first
      expect(sf.entry_numbers).to eql("123456")
    end
    it "should not replace entry reference numbers" do
      sf = create(:security_filing, :entry_reference_numbers=>"123456", :host_system=>'Kewill', :host_system_file_number=>'1870446', :last_event=>Time.zone.now)
      subject.parse_file xml_data, log
      sf = SecurityFiling.first
      expect(sf.entry_reference_numbers).to eql("123456")
    end
    it "should not process files with outdated event times" do
      sf = create(:security_filing, :host_system=>'Kewill', :host_system_file_number=>'1870446', :last_event=>Time.zone.now)
      subject.parse_file xml_data, log
      # Just pick a piece of informaiton from the file that's not in the create create and ensure it's not there
      sf = SecurityFiling.first
      expect(sf.transaction_number).to be_nil

      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_INFO)[0].message).to eq "Security filing not updated: file contained outdated info."
    end
    it "should update existing security filing and replace lines" do
      # This also tests that we're comparing exported from source using >= by using the same export timestamp in factory and parse call (timestamp manually extracted from test file)
      sf = create(:security_filing, :host_system=>'Kewill', :host_system_file_number=>'1870446', :last_event=>Time.iso8601("2012-11-27T07:20:01.565-05:00"))
      sf.security_filing_lines.create!(:line_number=>7, :quantity=>1)
      subject.parse_file xml_data, log
      sf.reload
      expect(sf.booking_number).to eq('BKING')
      expect(sf.security_filing_lines.size).to eq(2)
      expect(sf.security_filing_lines.collect {|ln| ln.line_number}).to eq([1, 2])
    end
    it "should set amazon bucket & path" do
      subject.parse_file xml_data, log, :bucket=>"bucket", :key => "isf_2435412_20210914_20131118145402586.1384804944.xml"
      sf = SecurityFiling.first
      expect(sf.last_file_bucket).to eq('bucket')
      expect(sf.last_file_path).to eq('isf_2435412_20210914_20131118145402586.1384804944.xml')
    end
    it "should lock entry for update" do
      expect(Lock).to receive(:acquire).with("SecurityFiling-Kewill-1870446").and_yield()
      expect(Lock).to receive(:with_lock_retry).with(kind_of(SecurityFiling)).and_yield()

      subject.parse_file xml_data, log
      expect(SecurityFiling.first).not_to be_nil
    end
    it "should raise exception if host_system_file_number is blank" do
      dom = REXML::Document.new xml_data
      dom.root.elements['ISF_SEQ_NBR'].text=''

      expect {subject.parse_file dom.to_s, log}.to raise_error "ISF_SEQ_NBR is required."
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "ISF_SEQ_NBR is required."
    end

    it "should raise exception if last event time is missing" do
      dom = REXML::Document.new xml_data
      dom.elements.delete_all("IsfHeaderData/events[EVENT_NBR='8' or EVENT_NBR='20' or EVENT_NBR='21']")

      expect {subject.parse_file dom.to_s, log}.to raise_error "At least one 'events' element with an 'EVENT_DATE' child and EVENT_NBR 21 or 8 must be present in the XML."
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "At least one 'events' element with an 'EVENT_DATE' child and EVENT_NBR 21 or 8 must be present in the XML."
    end

    it "parses a document with only event type 8, adding notes, but not removing existing info" do
      dom = REXML::Document.new xml_data

      dom.elements.delete_all("IsfHeaderData/lines")
      dom.elements.delete_all("IsfHeaderData/events[EVENT_NBR != '8']")

      notes = [
        "2012-11-27 09:15 EST: Bill Nbr: KKLUXM02368200. Disposition Cd: S2",
        "2012-11-27 09:15 EST: NO BILL MATCH (NOT ON FILE)"
      ]
      sf = create(:security_filing, :host_system=>'Kewill', :host_system_file_number=>'1870446', :last_event=>Time.iso8601("2012-11-27T07:20:01.565-05:00"),
        :po_numbers=>"A\nB", countries_of_origin: "C\nD", notes: notes.join("\n"))
      sf.security_filing_lines.create!(:line_number=>7, :quantity=>1)

      expect {subject.parse_file dom.to_s, log}.not_to raise_error

      saved = SecurityFiling.first
      expect(saved).to eq sf
      expect(saved.security_filing_lines.size).to eq 1
      expect(saved.po_numbers).to eq "A\nB"
      expect(saved.countries_of_origin).to eq "C\nD"
      # Make sure existing notes are retained, and existing note lines are not duplicated
      expect(saved.notes.split("\n")).to eq [
        "2012-11-27 09:15 EST: Bill Nbr: KKLUXM02368200. Disposition Cd: S2",
        "2012-11-27 09:15 EST: NO BILL MATCH (NOT ON FILE)",
        "2012-11-27 09:15 EST: Bill Nbr: YASVNLTPE0031400. Disposition Cd: S1",
        "2012-11-27 09:15 EST: BILL ON FILE",
        "2012-11-27 09:15 EST: All Bills Matched"
      ]
    end
    it "uses event date 20 as last event date if 21 or 8 are not present" do
      dom = REXML::Document.new xml_data

      dom.elements.delete_all("IsfHeaderData/events[EVENT_NBR != '20']")

      expect {subject.parse_file dom.to_s, log}.not_to raise_error

      saved = SecurityFiling.first
      expect(saved).not_to be_nil

      expect(saved.last_event).to eq ActiveSupport::TimeZone["UTC"].parse "2012-11-27T09:14:02.000-05:00"
    end
  end
  describe "parse_dom" do
    let (:dom) { REXML::Document.new xml_data }
    let (:security_filing) { create(:security_filing) }

    it "should create security filing" do
      sf = subject.parse_dom dom, security_filing, "bucket", "file.txt"

      expect(sf.last_file_bucket).to eq("bucket")
      expect(sf.last_file_path).to eq("file.txt")
      expect(sf.transaction_number).to eq("31671445820402")
      expect(sf.importer_account_code).to eq('EDDIEX')
      expect(sf.broker_customer_number).to eq('EDDIE')
      expect(sf.importer_tax_id).to eq('27-058606000')
      expect(sf.transport_mode_code).to eq('11')
      expect(sf.scac).to eq('KKLU')
      expect(sf.booking_number).to eq('BKING')
      expect(sf.vessel).to eq('VSL')
      expect(sf.voyage).to eq('VOY')
      expect(sf.lading_port_code).to eq('PL')
      expect(sf.unlading_port_code).to eq('UL')
      expect(sf.entry_port_code).to eq('PE')
      expect(sf.status_code).to eq('ACCNOMATCH')
      expect(sf.master_bill_of_lading).to eq('KKLUXM02368200')
      expect(sf.house_bills_of_lading).to eq('HBSCHBL123')
      expect(sf.container_numbers).to eq('KKFU1694054')
      expect(sf.entry_numbers).to eq('31619212983')
      expect(sf.entry_reference_numbers).to eq('1921298')
      expect(sf.file_logged_date.to_i).to eq(Time.utc(2012, 11, 27, 11, 40, 10).to_i)
      expect(sf.first_sent_date.to_i).to eq(Time.utc(2012, 11, 27, 14, 13, 36).to_i)
      expect(sf.first_accepted_date.to_i).to eq(Time.utc(2012, 11, 27, 14, 14, 2).to_i)
      expect(sf.last_sent_date.to_i).to eq(Time.utc(2012, 11, 27, 15, 13, 36).to_i)
      expect(sf.last_accepted_date.to_i).to eq(Time.utc(2012, 11, 27, 15, 14, 2).to_i)
      expect(sf.estimated_vessel_load_date).to eq Time.iso8601("2012-11-30T00:00:00-05:00").to_date
      expect(sf.estimated_vessel_sailing_date).to eq Time.iso8601("2014-06-26T00:00:00-04:00").to_date
      expect(sf.estimated_vessel_arrival_date).to eq Time.iso8601("2014-08-04T00:00:00-04:00").to_date
      expect(sf.po_numbers).to eq("0425694\n0425697")
      expect(sf.cbp_updated_at.to_date).to eq(Date.new(2012, 11, 27))
      expect(sf.status_description).to eq("Accepted No Bill Match")
      expect(sf.manufacturer_names).to eq("KINGTAI INDUSTRIAL (XIAMEN) CO., LT \nMANUFACTURER USED FOR TESTING ONLY")

      expect(sf.security_filing_lines.size).to eq(2)
      ln = sf.security_filing_lines.find {|ln| ln.line_number == 1}
      expect(ln.part_number).to eq('023-2214')
      expect(ln.quantity).to eq(0)
      expect(ln.hts_code).to eq('940430')
      expect(ln.po_number).to eq('0425694')
      expect(ln.commercial_invoice_number).to eq('CIN')
      expect(ln.mid).to eq("MID")
      expect(ln.country_of_origin_code).to eq('CN')
      expect(ln.manufacturer_name).to eq('KINGTAI INDUSTRIAL (XIAMEN) CO., LT')

    end
    it "should build notes" do
      # skipping events 19, 20, 21
      sf = subject.parse_dom dom, security_filing
      expect(sf.notes.lines("\n").collect {|ln| ln.strip}).to eq([
        "2012-11-27 06:40 EST: EDI Received",
        "2012-11-27 06:40 EST: Logged",
        "2012-11-27 09:13 EST: ISF Queued to Send to Customs - DANA",
        "2012-11-27 09:14 EST: ISF issued as a Compliance Transaction (CT)",
        "2012-11-27 09:14 EST: CBP Accepted - ISF ACCEPTED",
        "2012-11-27 09:14 EST: Submission Type - 1 : Importer Security Filing 10 (ISF-10)",
        "2012-11-27 09:15 EST: Bill Nbr: KKLUXM02368200. Disposition Cd: S2",
        "2012-11-27 09:15 EST: NO BILL MATCH (NOT ON FILE)",
        "2012-11-27 09:15 EST: Bill Nbr: YASVNLTPE0031400. Disposition Cd: S1",
        "2012-11-27 09:15 EST: BILL ON FILE",
        "2012-11-27 09:15 EST: All Bills Matched",
        "2012-11-27 10:13 EST: ISF Queued to Send to Customs - DANA",
        "2012-11-27 10:14 EST: ISF issued as a Compliance Transaction (CT)",
        "2012-11-27 10:14 EST: CBP Accepted - ISF ACCEPTED",
        "2012-11-27 10:14 EST: Submission Type - 1 : Importer Security Filing 10 (ISF-10)",
        "2014-06-26 00:00 EDT: Estimate Sailing",
        "2014-08-04 00:00 EDT: Estimated Arrival"
      ])
    end
    it "should handle multiple brokerrefs segments" do
      ref = dom.root.add_element("brokerrefs")
      ref.add_element("BROKER_FILER_CD").text="316"
      ref.add_element("ENTRY_NBR").text="12345678"
      ref.add_element("BROKER_REF_NO").text="XYZ"
      sf = subject.parse_dom dom, security_filing
      expect(sf.entry_numbers).to eq("31619212983\n31612345678")
      expect(sf.entry_reference_numbers).to eq("1921298\nXYZ")
    end
    it "should handle multiple container numbers" do
      ref = dom.root.add_element("containers")
      ref.add_element("CONTAINER_NBR").text="CON"
      sf = subject.parse_dom dom, security_filing
      expect(sf.container_numbers).to eq("KKFU1694054\nCON")
    end
    it "should handle multiple house bills" do
      ref = dom.root.add_element("bols")
      ref.add_element("MASTER_BILL_NBR").text="XM02368200"
      ref.add_element("MASTER_SCAC_CD").text="KKLU"
      ref.add_element("HOUSE_BILL_NBR").text='XXXX'
      ref.add_element("HOUSE_SCAC_CD").text='YYYY'
      sf = subject.parse_dom dom, security_filing
      expect(sf.house_bills_of_lading).to eq("HBSCHBL123\nYYYYXXXX")
    end
    it "should set countries of origin" do
      sf = subject.parse_dom dom, security_filing
      expect(sf.countries_of_origin).to eq("CN\nMX")
    end
    it "should remove lines not in updated xml" do
      security_filing.security_filing_lines.create! line_number: 1
      security_filing.security_filing_lines.create! line_number: 2
      dom.root.delete_element("/IsfHeaderData/lines[1]")

      sf = subject.parse_dom dom, security_filing
      # Since parse dom doesn't save, we're working w/ activerecord objects at this point that haven't actually
      # been persisted...just make sure we have 1 line remaining that's not marked for destruction
      lines = sf.security_filing_lines.find_all {|ln| !ln.destroyed?}
      expect(lines.size).to eq 1
      expect(lines[0].line_number).to eq 2
    end
    it "should set importer if it already exists by alliance customer number" do
      sf = subject.parse_dom dom, security_filing
      expect(sf.importer).to eq(customer)
    end
    it "should create new importer" do
      customer.system_identifiers.first.update! code: "NOTEDDIE"
      customer.update! alliance_customer_number: "NOTEDDIE"

      sf = subject.parse_dom dom, security_filing
      c = sf.importer
      expect(c.name).to eq('EDDIE')
      expect(c).to be_importer
      expect(c.alliance_customer_number).to eq('EDDIE')
      expect(c).to have_system_identifier("Customs Management", "EDDIE")
    end

    it "should not fail if there is no matching entity found by MID" do
      dom.root.get_elements("//IsfHeaderData/entities/MID").each do |el|
        el.text = "NONMATCHING"
      end

      sf = subject.parse_dom dom, security_filing
      sf.security_filing_lines.each do |line|
        expect(line.manufacturer_name).to be_nil
      end
    end

    context "status codes" do
      it "sets ACCNOMATCH description" do
        dom.root.elements['STATUS_CD'].text = "ACCNOMATCH"
        subject.parse_dom dom, security_filing
        expect(security_filing.status_description).to eq "Accepted No Bill Match"
      end

      it "sets DEL_ACCEPT description" do
        dom.root.elements['STATUS_CD'].text = "DEL_ACCEPT"
        security_filing.last_event = Time.zone.now
        subject.parse_dom dom, security_filing
        expect(security_filing.status_description).to eq "Delete Accepted"
        expect(security_filing.delete_accepted_date).to eq security_filing.last_event
      end

      it "sets ACCMATCH description" do
        dom.root.elements['STATUS_CD'].text = "ACCMATCH"
        security_filing.last_event = Time.zone.now
        subject.parse_dom dom, security_filing
        expect(security_filing.status_description).to eq "Accepted And Matched"
        expect(security_filing.ams_match_date).to eq security_filing.last_event
      end

      it "sets REPLACE description" do
        dom.root.elements['STATUS_CD'].text = "REPLACE"
        subject.parse_dom dom, security_filing
        expect(security_filing.status_description).to eq "Replaced"
      end

      it "sets ACCEPTED description" do
        dom.root.elements['STATUS_CD'].text = "ACCEPTED"
        subject.parse_dom dom, security_filing
        expect(security_filing.status_description).to eq "Accepted"
      end

      it "sets ACCWARNING description" do
        dom.root.elements['STATUS_CD'].text = "ACCWARNING"
        subject.parse_dom dom, security_filing
        expect(security_filing.status_description).to eq "Accepted With Warnings"
      end

      it "sets DELETED description" do
        dom.root.elements['STATUS_CD'].text = "DELETED"
        subject.parse_dom dom, security_filing
        expect(security_filing.status_description).to eq "Deleted"
      end
    end
  end
end
