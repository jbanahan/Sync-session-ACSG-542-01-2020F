require 'rexml/document'

describe OpenChain::CustomHandler::PoloCaEfocusGenerator do
  before :each do
    @tax_ids = ['806167003RM0001', '871349163RM0001', '866806458RM0001']
    @e1 = Factory(:entry, :importer_tax_id=>@tax_ids[0],
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
  describe "sync_xml" do
    it "should return array of tempfiles" do
      f = @g.sync_xml
      expect(f.size).to eq(1)
      expect(f.first.is_a?(Tempfile)).to be_truthy
      expect(f.first.path.end_with?(".xml")).to be_truthy
    end
    it "should find entries for all 3 importer ids" do
      @e2 = Factory(:entry, :importer_tax_id=>@tax_ids[1], :container_numbers=>'C', :master_bills_of_lading=>"M")
      @e3 = Factory(:entry, :importer_tax_id=>@tax_ids[2], :container_numbers=>'C', :master_bills_of_lading=>"M")
      expect(@g).to receive(:generate_xml_file).with(@e1, instance_of(StringIO))
      expect(@g).to receive(:generate_xml_file).with(@e2, instance_of(StringIO))
      expect(@g).to receive(:generate_xml_file).with(@e3, instance_of(StringIO))
      @g.sync_xml
    end
    it "should not find entries that are not for polo importer ids" do
      @e2 = Factory(:entry, :importer_tax_id=>'somethingelse', :container_numbers=>'C', :master_bills_of_lading=>"M")
      expect(@g).to receive(:generate_xml_file).with(@e1, instance_of(StringIO))
      expect(@g).not_to receive(:generate_xml_file).with(@e2, instance_of(StringIO))
      @g.sync_xml
    end
    it "should not find entries that don't need sync" do
      @e2 = Factory(:entry, :importer_tax_id=>@tax_ids[1], :updated_at=>1.day.ago, :container_numbers=>'C', :master_bills_of_lading=>"M")
      @e2.sync_records.create!(:trading_partner=>'polo_ca_efocus', :sent_at=>1.hour.ago, :confirmed_at=>10.minutes.ago)
      expect(@g).to receive(:generate_xml_file).with(@e1, instance_of(StringIO))
      expect(@g).not_to receive(:generate_xml_file).with(@e2, instance_of(StringIO))
      @g.sync_xml
    end
    it "should not send records without master bill" do
      @e1.update_attributes(:master_bills_of_lading=>"")
      expect(@g).not_to receive(:generate_xml_file)
      @g.sync_xml
    end
    it "should send with house but not container" do
      @e1.update_attributes(:house_bills_of_lading=>'')
      expect(@g).to receive(:generate_xml_file).with(@e1, instance_of(StringIO))
      @g.sync_xml
    end
    it "should send with container but not house" do
      @e1.update_attributes(:container_numbers=>'')
      expect(@g).to receive(:generate_xml_file).with(@e1, instance_of(StringIO))
      @g.sync_xml
    end
    it "should not send records without house bill or container" do
      @e1.update_attributes(:house_bills_of_lading=>"", :container_numbers=>"")
      expect(@g).not_to receive(:generate_xml_file)
      @g.sync_xml
    end

    # since we don't get an ack file
    it "should update sync records and include acknowledgement" do
      @g.sync_xml
      @e1.reload
      expect(@e1.sync_records.size).to eq(1)
      sr = @e1.sync_records.first
      expect(sr.trading_partner).to eq(OpenChain::CustomHandler::PoloCaEfocusGenerator::SYNC_CODE)
      expect(sr.sent_at).to be > 1.minute.ago
      expect(sr.confirmed_at).to be > sr.sent_at
    end

    it "should use existing sync record" do
      @e1.sync_records.create!(:trading_partner=>OpenChain::CustomHandler::PoloCaEfocusGenerator::SYNC_CODE, :sent_at=>1.day.ago, :confirmed_at=>12.hours.ago)
      @g.sync_xml
      @e1.reload
      expect(@e1.sync_records.size).to eq(1)
    end
    it "does not resend files that have the same fingerprint as previous ones" do
      data = "Testing"
      fingerprint = Digest::SHA1.hexdigest data
      @e1.sync_records.create!(:trading_partner=>OpenChain::CustomHandler::PoloCaEfocusGenerator::SYNC_CODE, :sent_at=>1.day.ago, :confirmed_at=>12.hours.ago, fingerprint: fingerprint)
      expect(@g).to receive(:generate_xml_file) do |entry, io|
        io << data
      end

      files = @g.sync_xml
      expect(files.size).to eq(0)
    end
    it "yields tempfile to block given if file's fingerprint changed" do
      files = []
      sync = []
      @g.sync_xml do |t, s|
        files << t.path
        sync << s
      end
      expect(files.size).to eq(1)
      expect(sync.length).to eq 1
      expect(sync.first).to eq @e1.sync_records.first
    end
    it "yields nothing if file fingerprint did not change" do
      data = "Testing"
      fingerprint = Digest::SHA1.hexdigest data
      @e1.sync_records.create!(:trading_partner=>OpenChain::CustomHandler::PoloCaEfocusGenerator::SYNC_CODE, :sent_at=>1.day.ago, :confirmed_at=>12.hours.ago, fingerprint: fingerprint)
      expect(@g).to receive(:generate_xml_file) do |entry, io|
        io << data
      end

      files = []
      @g.sync_xml {|t| files << t.path}
      expect(files.size).to eq(0)
    end

    context "bad port code" do
      before :each do
        @e1.update_attributes(:entry_port_code=>'000')
      end
      it "should email ralphlauren-ca@vandegriftinc.com" do
        @g.sync_xml
        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq(['ralphlauren-ca@vandegriftinc.com'])
        expect(mail.body).to include "Port code 0000 is not set in the Ralph Lauren e-Focus XML Generator."
      end
      it "should not generate file" do
        expect(@g.sync_xml).to eq([])
      end
      it "should generate sync record" do
        # so we don't keep resending error emails
        @g.sync_xml
        @e1.reload
        expect(@e1.sync_records.size).to eq(1)
      end
    end
  end

  describe "generate_xml_file" do
    def get_entry_element
      io = StringIO.new
      @g.generate_xml_file @e1, io
      io.rewind
      doc = REXML::Document.new io.read
      expect(doc.root.elements.to_a("entry").size).to eq(1)
      doc.root.elements['entry']
    end
    it "should generate base xml" do
      e = get_entry_element
      expect(e.elements["entry-number"].text).to eq(@e1.entry_number)
      expect(e.elements["broker-reference"].text).to eq(@e1.broker_reference)
      expect(e.elements["broker-importer-id"].text).to eq("RALPLA")
      expect(e.elements["broker-id"].text).to eq("VFI")
      expect(e.elements["import-date"].text).to eq(@e1.arrival_date.strftime(@date_format))
      expect(e.elements["documents-received-date"].text).to eq(@e1.docs_received_date.strftime(@date_format))
      expect(e.elements["in-customs-date"].text).to eq(@e1.across_sent_date.strftime(@date_format))
      expect(e.elements["out-customs-date"].text).to eq(@e1.release_date.strftime(@date_format))
      expect(e.elements["available-to-carrier-date"].text).to eq(@e1.release_date.strftime(@date_format))
      expect(e.elements['vessel-name'].text).to eq(@e1.vessel)
      expect(e.elements['voyage'].text).to eq(@e1.voyage)
      expect(e.elements['total-duty'].text).to eq(@e1.total_duty.to_s)
      expect(e.elements['total-tax'].text).to eq(@e1.total_gst.to_s)
      expect(e.elements['total-invoice-value'].text).to eq(@e1.total_invoiced_value.to_s)
      expect(e.elements['do-issued-date'].text).to eq(@e1.first_do_issued_date.strftime(@date_format))
      expect(e.elements.to_a.size).to eq(21)
    end
    it "should truncate house bills longer than 16 characters" do
      @e1.house_bills_of_lading = "HB12345678901234567890"
      @e1.master_bills_of_lading = "B"
      expect(get_entry_element.elements['master-bill'].elements['house-bill'].text).to eq("HB12345678901234")
    end
    it "should write multiple house bills" do
      @e1.house_bills_of_lading = "HB1 HB2"
      @e1.master_bills_of_lading = "X"
      bol = get_entry_element.elements['master-bill']
      expect(['HB1', 'HB2']).to eq(bol.elements.to_a('house-bill').collect {|el| el.text})
    end
    it "should write master bill" do
      @e1.master_bills_of_lading = "MB1 MB2"
      bols = get_entry_element.elements.to_a('master-bill')
      expect(["MB1", "MB2"]).to eq(bols.collect {|el| el.elements['number'].text})
    end
    it "should write multiple containers" do
      @e1.container_numbers = "C1 C2 C3"
      conts = get_entry_element.elements.to_a('container')
      expect(conts.size).to eq(3)
      expect(["C1", "C2", "C3"]).to eq(conts.collect {|el| el.text})
    end
    it "should not write empty values" do
      @e1.voyage = ''
      expect(get_entry_element.elements['voyage']).to be_nil
    end
    it "should map transport_mode_codes" do
      # US Customs code for mode of transportation, use A = Air = 1, L = Truck = 2, O = Vessel = 9, R = Rail = 6, 7=F,M = 3, or P = Mail
      {'1'=>'A', '2'=>'L', '3'=>'M', '6'=>'R', '7'=>'F', '9'=>'O'}.each do |fen, ohl|
        @f.unlink if @f
        @f = Tempfile.new('pcefg')
        @e1.transport_mode_code = fen
        expect(get_entry_element.elements['mode-of-transportation'].text).to eq(ohl)
      end
    end
    it "should map VAR if multiple countries of origin" do
      @e1.origin_country_codes = "CN TW"
      expect(get_entry_element.elements['country-origin'].text).to eq('VAR')
    end
    it "should use first if multiple countries of export" do
      @e1.export_country_codes = "CN TW"
      expect(get_entry_element.elements['country-export'].text).to eq('CN')
    end
    it "should use port codes table for unlading port codes" do
      p = Factory(:port, :cbsa_port=>'0009', :unlocode=>'CAHAL')
      @e1.entry_port_code = '9'
      expect(get_entry_element.elements['port-unlading'].text).to eq('CAHAL')
    end
  end

  describe "ftp_credentials" do
    it "should use the ftp2 credentials" do
      g = OpenChain::CustomHandler::PoloCaEfocusGenerator.new
      expect(g).to receive(:remote_file_name).and_return 'xyz.xml'

      c = g.ftp_credentials
      expect(c[:server]).to eq 'ftp2.vandegriftinc.com'
      expect(c[:username]).to eq 'VFITRACK'
      expect(c[:password]).to eq 'RL2VFftp'
      expect(c[:folder]).to eq 'to_ecs/Ralph_Lauren/efocus_ca_dev'
      expect(c[:remote_file_name]).to eq 'xyz.xml'
    end
  end

  describe "run_schedulable" do
    it "implements SchedulableJob interface" do
      expect_any_instance_of(described_class).to receive(:ftp_file)
      described_class.run_schedulable

      expect(SyncRecord.first.syncable).to eq @e1
    end
  end

  describe "generate" do
    it "generates xml and ftps it" do
      sync = SyncRecord.new trading_partner: "test"
      expect(subject).to receive(:sync_xml).and_yield "file", sync
      expect(subject).to receive(:ftp_sync_file).with "file", sync

      subject.generate
      expect(sync.persisted?).to eq true
    end
  end
end
