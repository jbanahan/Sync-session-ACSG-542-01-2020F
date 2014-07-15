require 'spec_helper'

describe OpenChain::CustomHandler::KewillIsfXmlParser do
  before :each do
    @path = 'spec/support/bin/isf_sample.xml'
    @k = OpenChain::CustomHandler::KewillIsfXmlParser
    @est = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
  end
  describe 'process_past_days' do
    it "should delay processing" do
      @k.should_receive(:delay).exactly(3).times.and_return(@k)
      @k.should_receive(:process_day).exactly(3).times
      @k.process_past_days 3
    end
  end
  describe 'process_day' do
    it 'should process all files from the given day' do
      d = Date.new
      OpenChain::S3.should_receive(:integration_keys).with(d, ["//opt/wftpserver/ftproot/www-vfitrack-net/_kewill_isf", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_kewill_isf"]).and_yield("a").and_yield("b")
      OpenChain::S3.should_receive(:get_data).with(OpenChain::S3.integration_bucket_name,"a").and_return("x")
      OpenChain::S3.should_receive(:get_data).with(OpenChain::S3.integration_bucket_name,"b").and_return("y")
      @k.should_receive(:parse).with("x",{:bucket=>OpenChain::S3.integration_bucket_name,:key=>"a",:imaging=>false})
      @k.should_receive(:parse).with("y",{:bucket=>OpenChain::S3.integration_bucket_name,:key=>"b",:imaging=>false})
      @k.process_day d
    end
  end
  describe :parse do
    it 'should process from text' do
      @k.parse IO.read(@path)
      sf = SecurityFiling.first
      sf.host_system_file_number.should == '1870446'
      sf.host_system.should == "Kewill"
      sf.last_event.to_i.should == Time.iso8601("2012-11-27T09:20:01.565-05:00").to_i
      # validate the time_to_process was recorded (use 10
      # to try to make sure we're recording milliseconds and not seconds)
      sf.time_to_process.should > 10
      sf.time_to_process.should < 1000 # NOTE: this fails if you're ever debugging the parser
    end
    it "should not process files with outdated event times" do
      sf = Factory(:security_filing,:host_system=>'Kewill',:host_system_file_number=>'1870446', :last_event=>Time.zone.now)
      @k.parse IO.read(@path)
      # Just pick a piece of informaiton from the file that's not in the Factory create and ensure it's not there
      sf = SecurityFiling.first
      sf.transaction_number.should be_nil
    end
    it "should update existing security filing and replace lines" do
      # This also tests that we're comparing exported from source using >= by using the same export timestamp in factory and parse call (timestamp manually extracted from test file)
      sf = Factory(:security_filing,:host_system=>'Kewill',:host_system_file_number=>'1870446', :last_event=>Time.iso8601("2012-11-27T07:20:01.565-05:00"))
      sf.security_filing_lines.create!(:line_number=>7,:quantity=>1)
      @k.parse IO.read(@path)
      sf.reload
      sf.booking_number.should == 'BKING'
      sf.should have(2).security_filing_lines
      sf.security_filing_lines.collect {|ln| ln.line_number}.should == [1,2]
    end
    it "should set amazon bucket & path" do
      @k.parse IO.read(@path), :bucket=>"bucket", :key => "isf_2435412_20210914_20131118145402586.1384804944.xml"
      sf = SecurityFiling.first
      sf.last_file_bucket.should == 'bucket'
      sf.last_file_path.should == 'isf_2435412_20210914_20131118145402586.1384804944.xml'
    end
    it "should lock entry for update" do
      Lock.should_receive(:acquire).with(Lock::ISF_PARSER_LOCK, times:3).and_yield()
      Lock.should_receive(:with_lock_retry).with(kind_of(SecurityFiling)).and_yield()

      @k.parse IO.read(@path)
      SecurityFiling.first.should_not be_nil
    end
    it "should raise exception if host_system_file_number is blank" do
      dom = REXML::Document.new File.new(@path)
      dom.root.elements['ISF_SEQ_NBR'].text=''

      expect{@k.parse dom.to_s}.to raise_error "ISF_SEQ_NBR is required."
    end
    it "parses a document with only event type 8, adding notes, but not removing existing info" do
      dom = REXML::Document.new File.new(@path)

      dom.elements.delete_all("IsfHeaderData/lines")
      dom.elements.delete_all("IsfHeaderData/events[EVENT_NBR != '8']")

      notes = [
        "2012-11-27 09:15 EST: Bill Nbr: KKLUXM02368200. Disposition Cd: S2",
        "2012-11-27 09:15 EST: NO BILL MATCH (NOT ON FILE)"
      ]
      sf = Factory(:security_filing,:host_system=>'Kewill',:host_system_file_number=>'1870446', :last_event=>Time.iso8601("2012-11-27T07:20:01.565-05:00"), 
        :po_numbers=>"A\nB", countries_of_origin: "C\nD", notes: notes.join("\n"))
      sf.security_filing_lines.create!(:line_number=>7,:quantity=>1)

      expect{@k.parse dom.to_s}.not_to raise_error

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
  end
  describe :parse_dom do
    before :each do
      @dom = REXML::Document.new File.new(@path)
      @sf = Factory(:security_filing)
    end

    it "should create security filing" do
      sf = @k.new.parse_dom @dom, @sf, "bucket", "file.txt"

      sf.last_file_bucket.should == "bucket"
      sf.last_file_path.should == "file.txt"
      sf.transaction_number.should == "31671445820402"
      sf.importer_account_code.should == 'EDDIEX' 
      sf.broker_customer_number.should == 'EDDIE'
      sf.importer_tax_id.should == '27-058606000'
      sf.transport_mode_code.should == '11'
      sf.scac.should == 'KKLU'
      sf.booking_number.should == 'BKING'
      sf.vessel.should == 'VSL'
      sf.voyage.should == 'VOY'
      sf.lading_port_code.should == 'PL'
      sf.unlading_port_code.should == 'UL'
      sf.entry_port_code.should == 'PE'
      sf.status_code.should == 'ACCNOMATCH'
      sf.late_filing.should be_false
      sf.master_bill_of_lading.should == 'KKLUXM02368200'
      sf.house_bills_of_lading.should == 'HBSCHBL123'
      sf.container_numbers.should == 'KKFU1694054'
      sf.entry_numbers.should == '31619212983' 
      sf.entry_reference_numbers.should == '1921298'
      sf.file_logged_date.to_i.should == Time.utc(2012,11,27,11,40,10).to_i
      sf.first_sent_date.to_i.should == Time.utc(2012,11,27,14,13,36).to_i
      sf.first_accepted_date.to_i.should == Time.utc(2012,11,27,14,14,2).to_i
      sf.last_sent_date.to_i.should == Time.utc(2012,11,27,15,13,36).to_i
      sf.last_accepted_date.to_i.should == Time.utc(2012,11,27,15,14,2).to_i
      sf.estimated_vessel_load_date.strftime("%Y%m%d") == @est.local(2012,11,30).strftime("%Y%m%d")
      sf.estimated_vessel_sailing_date.strftime("%Y%m%d") == @est.local(2014,6,26).strftime("%Y%m%d")
      sf.estimated_vessel_arrival_date.strftime("%Y%m%d") == @est.local(2014,8,4).strftime("%Y%m%d")
      sf.po_numbers.should == "0425694\n0425697"
      sf.cbp_updated_at.to_date.should == Date.new(2012, 11, 27)
      sf.status_description.should == "Accepted No Bill Match"
      sf.manufacturer_names.should == "KINGTAI INDUSTRIAL (XIAMEN) CO., LT \nMANUFACTURER USED FOR TESTING ONLY"

      sf.should have(2).security_filing_lines
      ln = sf.security_filing_lines.find {|ln| ln.line_number == 1}
      ln.part_number.should == '023-2214'
      ln.quantity.should == 0
      ln.hts_code.should == '940430'
      ln.po_number.should == '0425694'
      ln.commercial_invoice_number.should == 'CIN'
      ln.mid.should == "MID"
      ln.country_of_origin_code.should == 'CN'
      ln.manufacturer_name.should == 'KINGTAI INDUSTRIAL (XIAMEN) CO., LT' 
      
    end
    it "should build notes" do
      #skipping events 19, 20, 21
      sf = @k.new.parse_dom @dom, @sf
      sf.notes.lines("\n").collect {|ln| ln.strip}.should == [
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
      ]
    end
    it "should handle multiple brokerrefs segments" do
      ref = @dom.root.add_element("brokerrefs")
      ref.add_element("BROKER_FILER_CD").text="316"
      ref.add_element("ENTRY_NBR").text="12345678"
      ref.add_element("BROKER_REF_NO").text="XYZ"
      sf = @k.new.parse_dom @dom, @sf
      sf.entry_numbers.should == "31619212983\n31612345678"
      sf.entry_reference_numbers.should == "1921298\nXYZ"
    end
    it "should handle multiple container numbers" do
      ref = @dom.root.add_element("containers")
      ref.add_element("CONTAINER_NBR").text="CON"
      sf = @k.new.parse_dom @dom, @sf
      sf.container_numbers.should == "KKFU1694054\nCON"
    end
    it "should handle multiple house bills" do
      ref = @dom.root.add_element("bols")
      ref.add_element("MASTER_BILL_NBR").text="XM02368200"
      ref.add_element("MASTER_SCAC_CD").text="KKLU"
      ref.add_element("HOUSE_BILL_NBR").text='XXXX'
      ref.add_element("HOUSE_SCAC_CD").text='YYYY'
      sf = @k.new.parse_dom @dom, @sf
      sf.house_bills_of_lading.should == "HBSCHBL123\nYYYYXXXX"
    end
    it "should set countries of origin" do
      sf = @k.new.parse_dom @dom, @sf
      sf.countries_of_origin.should == "CN\nMX"
    end
    it "should set late filing to true" do
      @dom.root.elements['IS_SUBMIT_LATE'].text="Y"
      sf = @k.new.parse_dom @dom, @sf
      sf.should be_late_filing
    end
    it "should remove lines not in updated xml" do
      @sf.security_filing_lines.create! line_number: 1
      @sf.security_filing_lines.create! line_number: 2
      @dom.root.delete_element("/IsfHeaderData/lines[1]")

      sf = @k.new.parse_dom @dom, @sf
      # Since parse dom doesn't save, we're working w/ activerecord objects at this point that haven't actually
      # been persisted...just make sure we have 1 line remaining that's not marked for destruction
      lines = sf.security_filing_lines.find_all {|ln| !ln.destroyed?}
      expect(lines.size).to eq 1
      expect(lines[0].line_number).to eq 2
    end
    it "should set importer if it already exists by alliance customer number" do
      c = Factory(:company,:alliance_customer_number=>'EDDIE')
      sf = @k.new.parse_dom @dom, @sf
      sf.importer.should == c
    end
    it "should create new importer" do
      Factory(:company,:alliance_customer_number=>'NOTEDDIE')
      sf = @k.new.parse_dom @dom, @sf
      c = sf.importer
      c.name.should == 'EDDIE'
      c.should be_importer
      c.alliance_customer_number.should == 'EDDIE'
    end
    it "should not fail if there is no matching entity found by MID" do 
      @dom.root.get_elements("//IsfHeaderData/entities/MID").each do |el|
        el.text = "NONMATCHING"
      end

      sf = @k.new.parse_dom @dom, @sf
      sf.security_filing_lines.each do |line|
        line.manufacturer_name.should be_nil
      end
    end

    context "status codes" do
      it "sets ACCNOMATCH description" do
        @dom.root.elements['STATUS_CD'].text = "ACCNOMATCH"
        @k.new.parse_dom @dom, @sf
        expect(@sf.status_description).to eq "Accepted No Bill Match"
      end

      it "sets DEL_ACCEPT description" do
        @dom.root.elements['STATUS_CD'].text = "DEL_ACCEPT"
        @k.new.parse_dom @dom, @sf
        expect(@sf.status_description).to eq "Delete Accepted"
      end

      it "sets ACCMATCH description" do
        @dom.root.elements['STATUS_CD'].text = "ACCMATCH"
        @k.new.parse_dom @dom, @sf
        expect(@sf.status_description).to eq "Accepted And Matched"
      end

      it "sets REPLACE description" do
        @dom.root.elements['STATUS_CD'].text = "REPLACE"
        @k.new.parse_dom @dom, @sf
        expect(@sf.status_description).to eq "Replaced"
      end

      it "sets ACCEPTED description" do
        @dom.root.elements['STATUS_CD'].text = "ACCEPTED"
        @k.new.parse_dom @dom, @sf
        expect(@sf.status_description).to eq "Accepted"
      end

      it "sets ACCWARNING description" do
        @dom.root.elements['STATUS_CD'].text = "ACCWARNING"
        @k.new.parse_dom @dom, @sf
        expect(@sf.status_description).to eq "Accepted With Warnings"
      end

      it "sets DELETED description" do
        @dom.root.elements['STATUS_CD'].text = "DELETED"
        @k.new.parse_dom @dom, @sf
        expect(@sf.status_description).to eq "Deleted"
      end
    end
  end
end
