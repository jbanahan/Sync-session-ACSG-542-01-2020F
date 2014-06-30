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
    it "does not error if document with only event type 8 is found" do
      dom = REXML::Document.new File.new(@path)
      dom.root.get_elements("events/EVENT_NBR").each do |el|
        el.text = "8"
      end

      expect{@k.parse dom.to_s}.not_to raise_error
      # Make sure no security filing was created
      expect(SecurityFiling.first).to be_nil
    end
  end
  describe :parse_dom do
    before :each do
      @dom = REXML::Document.new File.new(@path)
      @sf = Factory(:security_filing)
    end

    it "should create security filing" do
      @k.new.parse_dom @dom, @sf, "bucket", "file.txt"

      SecurityFiling.all.count.should == 1
      sf = SecurityFiling.first
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
      sf.file_logged_date.should == Time.utc(2012,11,27,11,40,10)
      sf.first_sent_date.should == Time.utc(2012,11,27,14,13,36)
      sf.first_accepted_date.should == Time.utc(2012,11,27,14,14,2)
      sf.last_sent_date.should == Time.utc(2012,11,27,15,13,36)
      sf.last_accepted_date.should == Time.utc(2012,11,27,15,14,2)
      sf.estimated_vessel_load_date.strftime("%Y%m%d") == @est.local(2012,11,30).strftime("%Y%m%d")
      sf.estimated_vessel_arrival_date.strftime("%Y%m%d") == @est.local(2014,8,4).strftime("%Y%m%d")
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
      ln.manufacturer_name.should == 'KINGTAI INDUSTRIAL (XIAMEN) CO., LT' 
      # validate the time_to_process was recorded (use 10
      # to try to make sure we're recording milliseconds and not seconds)
      sf.time_to_process.should > 10
      sf.time_to_process.should < 1000 # NOTE: this fails if you're ever debugging the parser
    end
    it "should build notes" do
      #skipping events 19, 20, 21
      @k.new.parse_dom @dom, @sf
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
        "2012-11-27 10:14 EST: Submission Type - 1 : Importer Security Filing 10 (ISF-10)",
        "2014-08-04 00:00 EDT: Estimated Arrival"
      ]
    end
    it "should handle multiple brokerrefs segments" do
      ref = @dom.root.add_element("brokerrefs")
      ref.add_element("BROKER_FILER_CD").text="316"
      ref.add_element("ENTRY_NBR").text="12345678"
      ref.add_element("BROKER_REF_NO").text="XYZ"
      @k.new.parse_dom @dom, @sf
      sf = SecurityFiling.first
      sf.entry_numbers.should == "31619212983\n31612345678"
      sf.entry_reference_numbers.should == "1921298\nXYZ"
    end
    it "should handle multiple container numbers" do
      ref = @dom.root.add_element("containers")
      ref.add_element("CONTAINER_NBR").text="CON"
      @k.new.parse_dom @dom, @sf
      SecurityFiling.first.container_numbers.should == "KKFU1694054\nCON"
    end
    it "should handle multiple house bills" do
      ref = @dom.root.add_element("bols")
      ref.add_element("MASTER_BILL_NBR").text="XM02368200"
      ref.add_element("MASTER_SCAC_CD").text="KKLU"
      ref.add_element("HOUSE_BILL_NBR").text='XXXX'
      ref.add_element("HOUSE_SCAC_CD").text='YYYY'
      @k.new.parse_dom @dom, @sf
      SecurityFiling.first.house_bills_of_lading.should == "HBSCHBL123\nYYYYXXXX"
    end
    it "should set late filing to true" do
      @dom.root.elements['IS_SUBMIT_LATE'].text="Y"
      @k.new.parse_dom @dom, @sf
      SecurityFiling.first.should be_late_filing
    end
    it "should remove lines not in updated xml" do
      @k.new.parse_dom @dom, @sf
      sf = SecurityFiling.first
      sf.should have(2).security_filing_lines
      @dom.root.delete_element("/IsfHeaderData/lines[1]")
      @k.new.parse_dom @dom, sf
      SecurityFiling.first.should have(1).security_filing_lines
    end
    it "should set importer if it already exists by alliance customer number" do
      c = Factory(:company,:alliance_customer_number=>'EDDIE')
      @k.new.parse_dom @dom, @sf
      SecurityFiling.first.importer.should == c
    end
    it "should create new importer" do
      Factory(:company,:alliance_customer_number=>'NOTEDDIE')
      @k.new.parse_dom @dom, @sf
      c = SecurityFiling.first.importer
      c.name.should == 'EDDIE'
      c.should be_importer
      c.alliance_customer_number.should == 'EDDIE'
    end
    it "should not fail if there is no matching entity found by MID" do 
      @dom.root.get_elements("//IsfHeaderData/entities/MID").each do |el|
        el.text = "NONMATCHING"
      end

      @k.new.parse_dom @dom, @sf
      SecurityFiling.first.security_filing_lines.each do |line|
        line.manufacturer_name.should be_nil
      end
    end
  end
end
