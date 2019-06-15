require 'digest/md5'

describe OpenChain::CustomHandler::EddieBauer::EddieBauerFtzAsnGenerator do

  describe "run_schedulable" do
    it "should ftp file" do
      sync = SyncRecord.new trading_partner: "test"
      expect_any_instance_of(described_class).to receive(:find_entries).and_return(['ents'])
      expect_any_instance_of(described_class).to receive(:generate_file).with(['ents']).and_yield('x', {sent: [sync], ignored: []}, [])
      expect_any_instance_of(described_class).to receive(:ftp_sync_file).with('x', [sync])
      described_class.run_schedulable
      expect(sync.persisted?).to eq true
    end
  end

  describe "ftp_credentials" do
    it "should generate base credentials" do
      exp = {:server=>'connect.vfitrack.net',:username=>'eddiebauer',:password=>'zB1RrN9J',:folder=>"/test/to_eb/ftz_asn"}
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
  end

  describe "run_for_entries" do
    before :each do
      @entries = []
      @file = "file data"
      @entry = Factory(:entry)
      @sync_record = SyncRecord.new syncable: @entry, trading_partner: "partner"
    end
    it "generates file and saves yielded sync records and ftps yield file" do

      expect(subject).to receive(:generate_file).with(@entries).and_yield(@file, {sent: [@sync_record], ignored: []}, [])
      expect(subject).to receive(:ftp_sync_file).with @file, [@sync_record]

      subject.run_for_entries @entries

      expect(@sync_record).to be_persisted
    end

    it "rolls back all sync records saved if ftp fails" do
      expect(subject).to receive(:generate_file).with(@entries).and_yield(@file, {sent: [@sync_record], ignored: []}, [])
      expect(subject).to receive(:ftp_sync_file).with(@file, [@sync_record]).and_raise StandardError, "Error"

      expect {subject.run_for_entries @entries}.to raise_error StandardError, "<ul><li>Error</li></ul>"
      expect(@sync_record).not_to be_persisted
    end

    it "combines errors together into one mega error" do
      expect(subject).to receive(:generate_file).with(@entries).and_yield(@file, {sent: [@sync_record], ignored: []}, [StandardError.new("Error 1"), StandardError.new("Error 2")])
      expect(subject).to receive(:ftp_sync_file).with(@file, [@sync_record])


      expect {subject.run_for_entries @entries}.to raise_error StandardError, "<ul><li>Error 1</li><li>Error 2</li></ul>"
      expect(@sync_record).to be_persisted
    end
  end

  describe "generate_file" do

    before(:each) do
      @ent = Factory(:entry, updated_at:1.minute.ago, broker_reference: "broker-ref")
    end

    context "changed" do
      before :each do
        expect(subject).to receive(:generate_data_for_entry).with(@ent).and_return 'abc'
      end

      it "should generate and yeild file data for new entry data" do
        subject.generate_file([@ent]) do |file, sync_records, errors|
          file.rewind
          expect(file.read).to eq "abc"

          expect(sync_records[:sent].size).to eq 1
          sr = sync_records[:sent].first
          expect(sr).not_to be_persisted
          expect(sr.syncable).to eq @ent
          expect(sr.trading_partner).to eq described_class::SYNC_CODE
          expect(sr.sent_at).to be_within(1.minute).of Time.zone.now
          expect(sr.fingerprint).to eq Digest::MD5.hexdigest("abc")

          expect(errors.size).to eq 0
        end
      end
    end

    context "existing sync record" do

      before :each do
        expect(subject).to receive(:generate_data_for_entry).with(@ent).and_return 'abc'
        @sr = @ent.sync_records.create!(trading_partner:'EBFTZASN', fingerprint:Digest::MD5.hexdigest('abc'), sent_at: Time.zone.now - 1.day)
      end

      it "writes a blank file and updates sync record's ignore_updates_before attribute" do
        sent_at = @sr.sent_at

        subject.generate_file([@ent]) do |file, sync_records, errors|
          file.rewind
          expect(file.read).to be_blank
          expect(sync_records[:sent].length).to eq 0
          expect(sync_records[:ignored].length).to eq 1
          sr = sync_records[:ignored].first
          expect(sr).to be_changed
          expect(sr.ignore_updates_before).to be_within(2.minutes).of Time.zone.now
          expect(sr.sent_at.to_i).to eq sent_at.to_i

          expect(errors.size).to eq 0
        end
      end

      it "should write data if sync record is set to be resent" do
        @sr.update_attributes! sent_at: nil

        subject.generate_file([@ent]) do |file, sync_records, errors|
          file.rewind
          expect(file.read).to eq "abc"
          expect(sync_records[:sent].size).to eq 1
          expect(sync_records[:sent].first.sent_at).to be_within(1.minute).of Time.zone.now
        end
      end

      it "writes data if fingerprint differs from before" do
        @sr.update_attributes! fingerprint: "notanmd5hash"

        subject.generate_file([@ent]) do |file, sync_records, errors|
          file.rewind
          expect(file.read).to eq "abc"
          expect(sync_records[:sent].size).to eq 1
          expect(sync_records[:sent].first.sent_at).to be_within(1.minute).of Time.zone.now
        end
      end
    end

    context "error handling" do

      before :each do
        @ent2 = Factory(:entry)
      end

      it 'handles errors raised for a specific dataset generation without blowing up the whole run' do
        expect(subject).to receive(:generate_data_for_entry).with(@ent).and_raise "An Error"
        expect(subject).to receive(:generate_data_for_entry).with(@ent2).and_return "data"

        subject.generate_file([@ent, @ent2]) do |file, sync_records, errors|
          file.rewind
          expect(file.read).to eq "data"
          expect(sync_records[:sent].size).to eq 1
          expect(sync_records[:sent].first.syncable).to eq @ent2
          expect(sync_records[:sent].first.sent_at).to be_within(1.minute).of Time.zone.now

          expect(errors.size).to eq 1
          expect(errors.first.message).to eq "File ##{@ent.broker_reference}: An Error"
        end
      end
    end
  end
  describe "find_entries" do
    before :each do
      @entry  = Factory(:entry,customer_number:'EDDIEFTZ',
        broker_invoice_total:45,file_logged_date:Date.new(2014,5,1),
        last_exported_from_source:1.day.ago)
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
    it "should not send records that have been sent before where sent at > updated_at" do
      @entry.sync_records.create!(trading_partner:described_class::SYNC_CODE,sent_at:1.hour.ago,confirmed_at:20.minutes.ago)
      @entry.update_attributes(updated_at:1.day.ago)
      expect(described_class.new.find_entries.to_a).to eq []
    end
    it "should send records that have not been confirmed" do
      @entry.sync_records.create!(trading_partner:described_class::SYNC_CODE,sent_at:1.hour.ago)
      expect(described_class.new.find_entries.to_a).to eq [@entry]
    end
    it "should not send records that have been confirmed" do
      @entry.sync_records.create!(trading_partner:described_class::SYNC_CODE,sent_at:1.hour.ago,confirmed_at:20.minutes.ago)
      @entry.update_attributes(updated_at:1.day.ago)
      expect(described_class.new.find_entries.to_a).to eq []
    end
    it "should not send records where updated_at < ignore_updates_before" do
      @entry.sync_records.create!(trading_partner:described_class::SYNC_CODE,sent_at:10.days.ago,confirmed_at:2.days.ago,ignore_updates_before:1.hour.ago)
      @entry.update_attributes(updated_at:1.day.ago)
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
    it "should optionally skip multi-container" do
      @entry.update_attributes(container_numbers:'1234567890 1234567890')
      expect(described_class.new(Rails.env,{'skip_long_containers'=>true}).find_entries).to be_empty
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
        arrival_date:ActiveSupport::TimeZone["UTC"].parse('2014-03-30'),
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
        part_number:'123-1234',
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
      expect(ln[160,10]).to eql(@entry.arrival_date.in_time_zone("UTC").strftime("%m/%d/%Y"))
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
      expect(ln[290,11]).to eql('00000000000') #gross weight is always zero now
      expect(ln[301,11]).to eql('00000012300') #net weight from gross weight field per SOP
      expect(ln[312,10]).to eql(@ci_tariff.hts_code)
      expect(ln[322,10].rstrip).to eq ''
    end
    it "should skip line with bad part number" do
      @ci_line.update_attributes(part_number:'DELL FLAT PANEL MONITOR')
      r = described_class.new.generate_data_for_entry(@entry)
      expect(r).to be_blank
    end
    it "should handle long vessel" do
      @entry.vessel = '123456789012345678'
      r = described_class.new.generate_data_for_entry(@entry)
      expect(r.lines.first[134,15]).to eq '123456789012345'
    end
    it "should handle style/color" do
      @ci_line.part_number = '123-1234~XYZ'
      @ci_line.save!
      ln = first_line
      expect(ln[243,20].rstrip).to eql('123-1234')
      expect(ln[263,3].rstrip).to eql('XYZ')
      expect(ln[266,4].rstrip).to eql('') #empty size
    end
    it "should handle style/size" do
      @ci_line.part_number = '123-1234~~FFFF'
      @ci_line.save!
      ln = first_line
      expect(ln[243,20].rstrip).to eql('123-1234')
      expect(ln[263,3].rstrip).to eql('')
      expect(ln[266,4].rstrip).to eql('FFFF') #empty size
    end
    it "should handle style/color/size" do
      @ci_line.part_number = '123-1234~XYZ~FFFF'
      @ci_line.save!
      ln = first_line
      expect(ln[243,20].rstrip).to eql('123-1234')
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
      @ci_line.commercial_invoice_tariffs.first.update_attributes(entered_value:0)
      @ci_line.commercial_invoice_tariffs.create!(hts_code:'8888888888',entered_value:1)
      r = described_class.new.generate_data_for_entry(@entry)
      expect(r.lines.count).to eql(1) #2 numbers should still be one line
      ln = r.lines.first
      expect(ln[312,10]).to eq '8888888888'
      expect(ln[322,10].rstrip).to eq @ci_tariff.hts_code
    end
  end
end
