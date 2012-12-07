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
      OpenChain::S3.should_receive(:integration_keys).with(d,"/opt/wftpserver/ftproot/www-vfitrack-net/_kewill_isf").and_yield("a").and_yield("b")
      OpenChain::S3.should_receive(:get_data).with(OpenChain::S3.integration_bucket_name,"a").and_return("x")
      OpenChain::S3.should_receive(:get_data).with(OpenChain::S3.integration_bucket_name,"b").and_return("y")
      @k.should_receive(:parse).with("x",{:bucket=>OpenChain::S3.integration_bucket_name,:key=>"a"})
      @k.should_receive(:parse).with("y",{:bucket=>OpenChain::S3.integration_bucket_name,:key=>"b"})
      @k.process_day d
    end
  end
  describe :parse do
    it 'should process from text' do
      @k.parse IO.read @path
      SecurityFiling.first.host_system_file_number.should == '1870446'
    end
  end
  describe :parse_dom do
    before :each do
      @dom = REXML::Document.new File.new(@path)
    end
    it "should create security filing" do
      @k.new(@dom).parse_dom
      SecurityFiling.all.count.should == 1
      sf = SecurityFiling.first
      sf.host_system.should == "Kewill"
      sf.host_system_file_number.should == "1870446"
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
      sf.file_logged_date.should == Time.utc(2012,11,27,11,40,10)
      sf.first_sent_date.should == Time.utc(2012,11,27,14,13,36)
      sf.first_accepted_date.should == Time.utc(2012,11,27,14,14,2)
      sf.last_sent_date.should == Time.utc(2012,11,27,15,13,36)
      sf.last_accepted_date.should == Time.utc(2012,11,27,15,14,2)
      sf.estimated_vessel_load_date.strftime("%Y%m%d") == @est.local(2012,11,30).strftime("%Y%m%d")
      sf.po_numbers.should == "0425694\n0425697"
      sf.should have(2).security_filing_lines
      ln = sf.security_filing_lines.find_by_line_number(1)
      ln.part_number.should == '023-2214'
      ln.quantity.should == 0
      ln.hts_code.should == '940430'
      ln.po_number.should == '0425694'
      ln.commercial_invoice_number.should == 'CIN'
      ln.mid.should == "MID"
      ln.country_of_origin_code.should == 'CN'
    end
    it "should set amazon bucket & path" do
      @k.new(@dom).parse_dom 'bucket', 'path'
      sf = SecurityFiling.first
      sf.last_file_bucket.should == 'bucket'
      sf.last_file_path.should == 'path'
    end
    it "should update existing security filing and replace lines" do
      sf = Factory(:security_filing,:host_system=>'Kewill',:host_system_file_number=>'1870446')
      sf.security_filing_lines.create!(:line_number=>7,:quantity=>1)
      @k.new(@dom).parse_dom
      sf.reload
      sf.booking_number.should == 'BKING'
      sf.should have(2).security_filing_lines
      sf.security_filing_lines.collect {|ln| ln.line_number}.should == [1,2]
    end
    it "should build notes" do
      #skipping events 19, 20, 21
      @k.new(@dom).parse_dom
      sf = SecurityFiling.first
      sf.notes.lines("\n").to_a.collect {|ln| ln.strip}.should == [
        "2012-11-27 06:40 EST: EDI Received",
        "2012-11-27 06:40 EST: Logged",
        "2012-11-27 09:13 EST: ISF Queued to Send to Customs - DANA",
        "2012-11-27 09:14 EST: ISF issued as a Compliance Transaction (CT)",
        "2012-11-27 09:14 EST: CBP Accepted - ISF ACCEPTED",
        "2012-11-27 09:14 EST: Submission Type - 1 : Importer Security Filing 10 (ISF-10)",
        "2012-11-27 09:15 EST: Bill Nbr: KKLUXM02368200. Disposition Cd: S2",
        "2012-11-27 09:15 EST: NO BILL MATCH (NOT ON FILE)",
        "2012-11-27 10:13 EST: ISF Queued to Send to Customs - DANA",
        "2012-11-27 10:14 EST: ISF issued as a Compliance Transaction (CT)",
        "2012-11-27 10:14 EST: CBP Accepted - ISF ACCEPTED",
        "2012-11-27 10:14 EST: Submission Type - 1 : Importer Security Filing 10 (ISF-10)"
      ]
    end
    it "should not update if last event is older than previous last event" do
      @dom.root.elements['events/EVENT_DATE'].text=Time.now.iso8601
      @k.new(@dom).parse_dom
      sf = SecurityFiling.first
      sf.last_event.should > 10.seconds.ago
      u_time = 1.day.ago
      sf.update_attributes(:updated_at=>u_time)

      #reprocess
      @dom = REXML::Document.new File.new(@path)
      @dom.root.elements['SCAC_CD'].text = 'NEW SCAC'
      @k.new(@dom).parse_dom
      SecurityFiling.all.should have(1).filing
      sf = SecurityFiling.first
      sf.scac.should == 'KKLU'
      sf.updated_at.to_i.should == u_time.to_i
    end
    it "should update if last event is same as previous last event" do
      @k.new(@dom).parse_dom
      sf = SecurityFiling.first
      @dom.root.elements['SCAC_CD'].text = 'NEW SCAC'
      @k.new(@dom).parse_dom
      SecurityFiling.all.should have(1).filing
      sf = SecurityFiling.first
      sf.scac.should == 'NEW SCAC'
    end
    it "should handle multiple brokerrefs segments" do
      ref = @dom.root.add_element("brokerrefs")
      ref.add_element("BROKER_FILER_CD").text="316"
      ref.add_element("ENTRY_NBR").text="12345678"
      ref.add_element("BROKER_REF_NO").text="XYZ"
      @k.new(@dom).parse_dom
      sf = SecurityFiling.first
      sf.entry_numbers.should == "31619212983\n31612345678"
      sf.entry_reference_numbers.should == "1921298\nXYZ"
    end
    it "should handle multiple container numbers" do
      ref = @dom.root.add_element("containers")
      ref.add_element("CONTAINER_NBR").text="CON"
      @k.new(@dom).parse_dom
      SecurityFiling.first.container_numbers.should == "KKFU1694054\nCON"
    end
    it "should handle multiple house bills" do
      ref = @dom.root.add_element("bols")
      ref.add_element("MASTER_BILL_NBR").text="XM02368200"
      ref.add_element("MASTER_SCAC_CD").text="KKLU"
      ref.add_element("HOUSE_BILL_NBR").text='XXXX'
      ref.add_element("HOUSE_SCAC_CD").text='YYYY'
      @k.new(@dom).parse_dom
      SecurityFiling.first.house_bills_of_lading.should == "HBSCHBL123\nYYYYXXXX"
    end
    it "should set late filing to true" do
      @dom.root.elements['IS_SUBMIT_LATE'].text="Y"
      @k.new(@dom).parse_dom
      SecurityFiling.first.should be_late_filing
    end
    it "should raise exception if host_system_file_number is blank" do
      @dom.root.elements['ISF_SEQ_NBR'].text=''
      lambda {@k.new(@dom).parse_dom}.should raise_error "ISF_SEQ_NBR is required."
    end
    it "should remove lines not in updated xml" do
      @k.new(@dom).parse_dom
      SecurityFiling.first.should have(2).security_filing_lines
      @dom.root.delete_element("/IsfHeaderData/lines[1]")
      @k.new(@dom).parse_dom
      SecurityFiling.first.should have(1).security_filing_lines
    end
    it "should set importer if it already exists by alliance customer number" do
      c = Factory(:company,:alliance_customer_number=>'EDDIE')
      @k.new(@dom).parse_dom
      SecurityFiling.first.importer.should == c
    end
    it "should create new importer" do
      Factory(:company,:alliance_customer_number=>'NOTEDDIE')
      @k.new(@dom).parse_dom
      c = SecurityFiling.first.importer
      c.name.should == 'EDDIE'
      c.should be_importer
      c.alliance_customer_number.should == 'EDDIE'
    end
  end
end
