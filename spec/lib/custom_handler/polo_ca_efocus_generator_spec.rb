require 'spec_helper'
require 'rexml/document'

describe OpenChain::CustomHandler::PoloCaEfocusGenerator do
  before :each do
    @tax_ids = OpenChain::CustomHandler::PoloCaEntryParser::POLO_IMPORTER_TAX_IDS
    @e1 = Factory(:entry,:importer_tax_id=>@tax_ids[0],
      :entry_number=>'123456789',
      :broker_reference=>'666666',
      :arrival_date=>5.days.ago,
      :across_sent_date=>4.days.ago,
      :release_date=>3.days.ago,
      :vessel=>'abc',
      :voyage=>'def',
      :transport_mode_code=>'1',
      :origin_country_codes => 'CN',
      :export_country_codes => 'TW',
      :total_units => 100,
      :total_duty => 200,
      :total_gst => 300,
      :total_invoiced_value => 400,
      :master_bills_of_lading => "ABC1234",
      :house_bills_of_lading => "HBOL1",
      :container_numbers=>"CONT1",
      :docs_received_date => 6.days.ago,
      :first_do_issued_date => 7.days.ago
    )
    @date_format = "%Y%m%d"
    @g = OpenChain::CustomHandler::PoloCaEfocusGenerator.new
  end
  describe :sync_xml do
    it "should return array of tempfiles" do
      f = @g.sync_xml
      f.size.should == 1
      f.first.is_a?(Tempfile).should be_true
      f.first.path.end_with?(".xml").should be_true
    end
    it "should find entries for all 3 importer ids" do
      @e2 = Factory(:entry,:importer_tax_id=>@tax_ids[1],:container_numbers=>'C',:master_bills_of_lading=>"M")
      @e3 = Factory(:entry,:importer_tax_id=>@tax_ids[2],:container_numbers=>'C',:master_bills_of_lading=>"M")
      @g.should_receive(:generate_xml_file).with(@e1,instance_of(Tempfile))
      @g.should_receive(:generate_xml_file).with(@e2,instance_of(Tempfile))
      @g.should_receive(:generate_xml_file).with(@e3,instance_of(Tempfile))
      @g.sync_xml
    end
    it "should not find entries that are not for polo importer ids" do
      @e2 = Factory(:entry,:importer_tax_id=>'somethingelse',:container_numbers=>'C',:master_bills_of_lading=>"M")
      @g.should_receive(:generate_xml_file).with(@e1,instance_of(Tempfile))
      @g.should_not_receive(:generate_xml_file).with(@e2,instance_of(Tempfile))
      @g.sync_xml
    end
    it "should not find entries that don't need sync" do
      @e2 = Factory(:entry,:importer_tax_id=>@tax_ids[1],:updated_at=>1.day.ago,:container_numbers=>'C',:master_bills_of_lading=>"M")
      @e2.sync_records.create!(:trading_partner=>'polo_ca_efocus',:sent_at=>1.hour.ago,:confirmed_at=>10.minutes.ago)
      @g.should_receive(:generate_xml_file).with(@e1,instance_of(Tempfile))
      @g.should_not_receive(:generate_xml_file).with(@e2,instance_of(Tempfile))
      @g.sync_xml
    end
    it "should not send records without master bill" do
      @e1.update_attributes(:master_bills_of_lading=>"")
      @g.should_not_receive(:generate_xml_file)
      @g.sync_xml
    end
    it "should send with house but not container" do
      @e1.update_attributes(:house_bills_of_lading=>'')
      @g.should_receive(:generate_xml_file).with(@e1,instance_of(Tempfile))
      @g.sync_xml
    end
    it "should send with container but not house" do
      @e1.update_attributes(:container_numbers=>'')
      @g.should_receive(:generate_xml_file).with(@e1,instance_of(Tempfile))
      @g.sync_xml
    end
    it "should not send records without house bill or container" do
      @e1.update_attributes(:house_bills_of_lading=>"",:container_numbers=>"")
      @g.should_not_receive(:generate_xml_file)
      @g.sync_xml
    end
    
    #since we don't get an ack file
    it "should update sync records and include acknowledgement" do
      @g.sync_xml
      @e1.reload
      @e1.should have(1).sync_records
      sr = @e1.sync_records.first
      sr.trading_partner.should == OpenChain::CustomHandler::PoloCaEfocusGenerator::SYNC_CODE
      sr.sent_at.should > 1.minute.ago
      sr.confirmed_at.should > sr.sent_at
    end

    it "should use existing sync record" do
      @e1.sync_records.create!(:trading_partner=>OpenChain::CustomHandler::PoloCaEfocusGenerator::SYNC_CODE,:sent_at=>1.day.ago,:confirmed_at=>12.hours.ago)
      @g.sync_xml
      @e1.reload
      @e1.should have(1).sync_records
    end
    context "bad port code" do
      before :each do 
        @e1.update_attributes(:entry_port_code=>'000')
      end
      it "should email ralphlauren-ca@vandegriftinc.com" do
        @g.sync_xml
        mail = ActionMailer::Base.deliveries.pop
        mail.to.should == ['ralphlauren-ca@vandegriftinc.com']
        mail.body.should include "Port code 0000 is not set in the Ralph Lauren e-Focus XML Generator."
      end
      it "should not generate file" do
        @g.sync_xml.should == [] 
      end
      it "should generate sync record" do
        #so we don't keep resending error emails
        @g.sync_xml
        @e1.reload
        @e1.should have(1).sync_records
      end
    end
  end

  describe :generate_xml_file do
    before :each do
      @f = Tempfile.new('pcefg')
    end
    after :each do
      @f.unlink if @f
    end
    def get_entry_element 
      @g.generate_xml_file @e1, @f
      doc = REXML::Document.new File.new(@f.path)
      doc.root.elements.to_a("entry").should have(1).element
      doc.root.elements['entry']
    end
    it "should generate base xml" do
      e = get_entry_element
      e.elements["entry-number"].text.should == @e1.entry_number
      e.elements["broker-reference"].text.should == @e1.broker_reference
      e.elements["broker-importer-id"].text.should == "RALPLA"
      e.elements["broker-id"].text.should == "VFI"
      e.elements["import-date"].text.should == @e1.arrival_date.strftime(@date_format)
      e.elements["documents-received-date"].text.should == @e1.docs_received_date.strftime(@date_format)
      e.elements["in-customs-date"].text.should == @e1.across_sent_date.strftime(@date_format)
      e.elements["out-customs-date"].text.should == @e1.release_date.strftime(@date_format)
      e.elements["available-to-carrier-date"].text.should == @e1.release_date.strftime(@date_format)
      e.elements['vessel-name'].text.should == @e1.vessel
      e.elements['voyage'].text.should == @e1.voyage
      e.elements['total-duty'].text.should == @e1.total_duty.to_s
      e.elements['total-tax'].text.should == @e1.total_gst.to_s
      e.elements['total-invoice-value'].text.should == @e1.total_invoiced_value.to_s
      e.elements['do-issued-date'].text.should == @e1.first_do_issued_date.strftime(@date_format)
      e.elements.to_a.should have(21).elements
    end
    it "should truncate house bills longer than 16 characters" do
      @e1.house_bills_of_lading = "HB12345678901234567890"
      @e1.master_bills_of_lading = "B"
      get_entry_element.elements['master-bill'].elements['house-bill'].text.should == "HB12345678901234"
    end
    it "should write multiple house bills" do
      @e1.house_bills_of_lading = "HB1 HB2"
      @e1.master_bills_of_lading = "X"
      bol = get_entry_element.elements['master-bill']
      ['HB1','HB2'].should == bol.elements.to_a('house-bill').collect {|el| el.text}
    end
    it "should write master bill" do
      @e1.master_bills_of_lading = "MB1 MB2"
      bols = get_entry_element.elements.to_a('master-bill')
      ["MB1","MB2"].should == bols.collect {|el| el.elements['number'].text}
    end
    it "should write multiple containers" do
      @e1.container_numbers = "C1 C2 C3"
      conts = get_entry_element.elements.to_a('container')
      conts.should have(3).items
      ["C1","C2","C3"].should == conts.collect {|el| el.text}
    end
    it "should not write empty values" do
      @e1.voyage = ''
      get_entry_element.elements['voyage'].should be_nil
    end
    it "should map transport_mode_codes" do
      #US Customs code for mode of transportation, use A = Air = 1, L = Truck = 2, O = Vessel = 9, R = Rail = 6, 7=F,M = 3, or P = Mail
      {'1'=>'A','2'=>'L','3'=>'M','6'=>'R','7'=>'F','9'=>'O'}.each do |fen,ohl|
        @f.unlink if @f
        @f = Tempfile.new('pcefg')
        @e1.transport_mode_code = fen
        get_entry_element.elements['mode-of-transportation'].text.should == ohl
      end
    end
    it "should map VAR if multiple countries of origin" do
      @e1.origin_country_codes = "CN TW"
      get_entry_element.elements['country-origin'].text.should == 'VAR'
    end
    it "should use first if multiple countries of export" do
      @e1.export_country_codes = "CN TW"
      get_entry_element.elements['country-export'].text.should == 'CN'
    end
    it "should use port codes table for unlading port codes" do
      p = Factory(:port,:cbsa_port=>'0009',:unlocode=>'CAHAL')
      @e1.entry_port_code = '9'
      get_entry_element.elements['port-unlading'].text.should == 'CAHAL'
    end
  end

  describe :ftp_xml_files do
    before :each do 
      @tempfiles = []
      @h = OpenChain::CustomHandler::PoloCaEfocusGenerator.new
    end
    after :each do 
      @tempfiles.each {|t| t.unlink}
    end
    it "should ftp the files to dev folder" do
      @h.stub(:remote_file_name).and_return('xyz.xml')
      3.times do |i| 
        t = Tempfile.new(["tf#{i}",".xml"])
        @tempfiles << t
        FtpSender.should_receive(:send_file,).with('ftp2.vandegriftinc.com','VFITRack','RL2VFftp',t,{:folder=>'to_ecs/Ralph_Lauren/efocus_ca_dev',:remote_file_name=>'xyz.xml'})
      end
      @h.ftp_xml_files @tempfiles
    end
    it "should set remote file name" do
      @h.remote_file_name.should match /VFITRACK[0-9]{14}\.xml/
    end
  end
end
