require "spec_helper"

describe OpenChain::CustomHandler::EddieBauer::EddieBauerFtzAsnGenerator do
  describe "run_schedulable" do
    it "should ftp file" do
      described_class.any_instance.should_receive(:find_entries).and_return(['ents'])
      described_class.any_instance.should_receive(:generate_file).with(['ents']).and_return('x')
      described_class.any_instance.should_receive(:ftp_file).with('x')
      described_class.run_schedulable
    end
  end
  describe "ftp_credentials" do
    it "should generate base credentials" do
      exp = {:server=>'connect.vfitrack.net',:username=>'eddiebauer',:password=>'antxsqt',:folder=>"/test/to_eb/ftz_asn"}
      found = described_class.new.ftp_credentials
      expect(found[:server]).to eq exp[:server]
      expect(found[:username]).to eq exp[:username]
      expect(found[:password]).to eq exp[:password]
    end
    it "should generate accurate file name" do
      expect(described_class.new.ftp_credentials[:remote_file_name]).to match /^FTZ_ASN_\d{14}\.txt$/
    end
    it "should generate prod folder" do
      expect(described_class.new('production').ftp_credentials[:folder]).to eq "/prod/to_eb/ftz_asn"
    end
    it "should generate test folder" do
      expect(described_class.new.ftp_credentials[:folder]).to eq "/test/to_eb/ftz_asn"
    end
    it "should generate test folder if not EDDIEFTZ customer" do
      expect(described_class.new('production',['OTHER']).ftp_credentials[:folder]).to eq "/test/to_eb/ftz_asn"
    end
  end
  describe "generate_file" do
    before(:each) do
      @ent = Factory(:entry)
      @g = described_class.new
      @g.should_receive(:generate_data_for_entry).with(@ent).and_return 'abc'
    end
    it "should link methods to find and generate" do
      tmp  = @g.generate_file [@ent]
      tmp.flush
      expect(IO.read(tmp.path)).to eq 'abc'
    end
    it "should write sync_records" do
      expect{@g.generate_file([@ent])}.to change(SyncRecord.where(trading_partner:'EBFTZASN'),:count).from(0).to(1)

    end
  end
  describe "find_entries" do
    before :each do
      @entry  = Factory(:entry,customer_number:'EDDIEFTZ',broker_invoice_total:45,file_logged_date:Date.new(2014,5,1))
      @rule_result = Factory(:business_validation_rule_result,state:'Pass')
      res = @rule_result.business_validation_result
      res.state = 'Pass'
      res.validatable = @entry
      res.save!
      @entry.reload
    end
    it "should find all that don't have sync records and have passed business rule states" do
      expect(described_class.new.find_entries.to_a).to eq [@entry]
    end
    it "should not send recrods that have been sent before" do
      @entry.sync_records.create!(trading_partner:described_class::SYNC_CODE)
      expect(described_class.new.find_entries.to_a).to eq []
    end
    it "should not find Review business rules state" do
      @rule_result.state = 'Review'
      @rule_result.save!
      res = @rule_result.business_validation_result
      res.state = 'Review'
      res.save!
      expect(described_class.new.find_entries.to_a).to be_empty
    end
    it "should not send if no broker invoice" do
      @entry.update_attributes(broker_invoice_total:0)
      expect(described_class.new.find_entries.to_a).to be_empty
    end
  end
  describe "generate_data_for_entry" do
    before(:each) do
      @entry = Factory(:entry,broker_reference:'1234567',
        entry_number:'31612345678',
        master_bills_of_lading:'MBOL',
        house_bills_of_lading:'HBOL',
        it_numbers:'ITNUM',
        first_it_date:Date.new(2014,3,31),
        transport_mode_code:'11',
        export_date:Date.new(2014,3,14),
        arrival_date:Date.new(2014,3,30),
        lading_port_code:'12345',
        unlading_port_code:'1234',
        total_packages:'101',
        carrier_code:'APLL',
        voyage:'VYG',
        vessel:'VES',
        container_numbers:'CONNUM'
      )
      @ci = Factory(:commercial_invoice,entry:@entry)
      @ci_line = Factory(:commercial_invoice_line,commercial_invoice:@ci,
        country_export_code:'HK',
        country_origin_code:'CN',
        po_number:'12345-001',
        part_number:'1234-ABC',
        mid:'mid',
        quantity:2000)
      @ci_tariff = Factory(:commercial_invoice_tariff,commercial_invoice_line:@ci_line,
        entered_value:1000.50,
        gross_weight:123,
        classification_qty_2:122, #net weight
        hts_code:'1234567890'
      )
    end
    def first_line
      described_class.new.generate_data_for_entry(@entry).lines.first
    end
    it "should make base data" do
      r = described_class.new.generate_data_for_entry(@entry)
      expect(r.lines.count).to eq 1
      ln = r.lines.first
      expect(ln[0,7]).to eq @entry.broker_reference
      expect(ln[7,35].rstrip).to eql(@entry.master_bills_of_lading)
      expect(ln[42,35].rstrip).to eql(@entry.house_bills_of_lading)
      expect(ln[77,23].rstrip).to eql(@entry.it_numbers)
      expect(ln[100,20].rstrip).to eql(@entry.container_numbers)
      expect(ln[120,10]).to eql('03/31/2014')
      expect(ln[130,4]).to eql(@entry.unlading_port_code)
      expect(ln[134,15].rstrip).to eql(@entry.vessel)
      expect(ln[149]).to eql('O')
      expect(ln[150,10]).to eql('03/14/2014')
      expect(ln[160,10]).to eql('03/30/2014')
      expect(ln[170,5]).to eql(@entry.lading_port_code)
      expect(ln[175,4]).to eql(@entry.unlading_port_code)
      expect(ln[179,9]).to eql('000000101')
      expect(ln[188,2]).to eql(@entry.transport_mode_code)
      expect(ln[190,4]).to eql(@entry.carrier_code)
      expect(ln[194,15].rstrip).to eql(@entry.voyage)
      expect(ln[209,2]).to eql(@ci_line.country_export_code)
      expect(ln[211,15].rstrip).to eql(@ci_line.po_number)
      expect(ln[226,2]).to eql(@ci_line.country_origin_code)
      expect(ln[228,15].rstrip).to eql(@ci_line.mid)
      expect(ln[243,20].rstrip).to eql(@ci_line.part_number)
      expect(ln[263,3].rstrip).to eql('') #empty color
      expect(ln[266,4].rstrip).to eql('') #empty size
      expect(ln[270,9]).to eql('000002000') #quantity
      expect(ln[279,11]).to eql('00000100050') #entered value
      expect(ln[290,11]).to eql('00000012300') #gross weight KGS
      expect(ln[301,11]).to eql('00000012200') #net weight from qty_2
      expect(ln[312,10]).to eql(@ci_tariff.hts_code)
      expect(ln[322,10].rstrip).to eq ''
    end
    it "should handle long vessel" do
      @entry.vessel = '123456789012345678'
      r = described_class.new.generate_data_for_entry(@entry)
      expect(r.lines.first[134,15]).to eq '123456789012345'
    end
    it "should handle style/color" do
      @ci_line.part_number = '12345-123~XYZ'
      @ci_line.save!
      ln = first_line
      expect(ln[243,20].rstrip).to eql('12345-123')
      expect(ln[263,3].rstrip).to eql('XYZ') 
      expect(ln[266,4].rstrip).to eql('') #empty size
    end
    it "should handle style/size" do
      @ci_line.part_number = '12345-123~~FFFF'
      @ci_line.save!
      ln = first_line
      expect(ln[243,20].rstrip).to eql('12345-123')
      expect(ln[263,3].rstrip).to eql('') 
      expect(ln[266,4].rstrip).to eql('FFFF') #empty size
    end
    it "should handle style/color/size" do
      @ci_line.part_number = '12345-123~XYZ~FFFF'
      @ci_line.save!
      ln = first_line
      expect(ln[243,20].rstrip).to eql('12345-123')
      expect(ln[263,3].rstrip).to eql('XYZ') 
      expect(ln[266,4].rstrip).to eql('FFFF') #empty size
    end
    it "should handle mode translations" do
      ['11','10'].each do |x|
        @entry.update_attributes(transport_mode_code:x)
        expect(first_line[149]).to eq 'O'
      end
      ['40','41'].each do |x|
        @entry.update_attributes(transport_mode_code:x)
        expect(first_line[149]).to eq 'A'
      end
      ['11','10'].each do |x|
        @entry.update_attributes(transport_mode_code:x)
        expect(first_line[149]).to eq 'O'
      end
    end
    it "should handle secondary HTS number" do
      @ci_line.commercial_invoice_tariffs.create!(hts_code:'8888888888')
      r = described_class.new.generate_data_for_entry(@entry)
      expect(r.lines.count).to eql(1) #2 numbers should still be one line
      ln = r.lines.first
      expect(ln[312,10]).to eql(@ci_tariff.hts_code)
      expect(ln[322,10].rstrip).to eq '8888888888'
    end
  end
end