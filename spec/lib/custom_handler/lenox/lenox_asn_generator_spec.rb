require 'spec_helper'

describe OpenChain::CustomHandler::Lenox::LenoxAsnGenerator do
  it "should email on LenoxBusinessLogicError" do
    g = described_class.new
    g.stub(:generate_header_rows).and_yield("x")
    g.stub(:generate_detail_rows).and_raise(described_class::LenoxBusinessLogicError)
    r = g.generate_tempfiles [Factory(:entry)]
    expect(r.size).to eq 2
    expect(Entry.first.sync_records.count).to eq 1 #write sync record on LenoxBusinessLogicError
    email = ActionMailer::Base.deliveries.last
    expect(email.subject).to eql("Lenox ASN Failure")
    expect(email.to).to eq ["lenox_us@vandegriftinc.com"]
  end

  describe :run_schedulable do
    it "should ftp_file" do
      ents = 'x'
      files = ['y','z']
      described_class.any_instance.should_receive(:find_entries).and_return(ents)
      described_class.any_instance.should_receive(:generate_tempfiles).with(ents).and_return(files)
      described_class.any_instance.should_receive(:ftp_file).with(files[0],{remote_file_name:'Vand_Header'})
      described_class.any_instance.should_receive(:ftp_file).with(files[1],{remote_file_name:'Vand_Detail'})
      described_class.run_schedulable
    end
  end

  describe "ftp_credentials" do
    it "should generate base non-production credentials" do
      exp = {:server=>'ftp.lenox.com',:username=>'vanvendortest',:password=>'$hipments',:folder=>"."}
      found = described_class.new.ftp_credentials
      expect(found[:server]).to eq exp[:server]
      expect(found[:username]).to eq exp[:username]
      expect(found[:password]).to eq exp[:password]
    end
    it "should generate base production credentials" do
      exp = {:server=>'ftp.lenox.com',:username=>'vanvendor',:password=>'$hipments',:folder=>"."}
      found = described_class.new(env:'production').ftp_credentials
      expect(found[:server]).to eq exp[:server]
      expect(found[:username]).to eq exp[:username]
      expect(found[:password]).to eq exp[:password]
    end
  end

  context :needs_data do    
    before :each do 
      @cdefs = described_class.prep_custom_definitions described_class::CUSTOM_DEFINITION_INSTRUCTIONS.keys
      @lenox = Factory(:company,alliance_customer_number:'LENOX',system_code:'LENOX')
      @vendor = Factory(:company,system_code:'LENOX-VENCODE')
      @entry = Factory(:entry,importer:@lenox,master_bills_of_lading:'MBOL',entry_number:'11312345678',
        vessel:'VES',customer_references:'P14010337',export_date:Date.new(2014,1,16),
        lading_port_code:'12345',unlading_port_code:'4321',transport_mode_code:'11')
      @ci = Factory(:commercial_invoice,entry:@entry,gross_weight:99,invoice_number:'123456',invoice_date:Date.new(2014,3,17))
      @ci_line = Factory(:commercial_invoice_line,commercial_invoice:@ci,po_number:'ponum',
        quantity:10, country_origin_code:'CN',part_number:'partnum',unit_price:100.10,line_number:2
      )
      @product = Factory(:product,importer:@lenox,unique_identifier:'LENOX-partnum')
      @product.update_custom_value!(@cdefs[:product_units_per_set],2)
      @order = Factory(:order,importer:@lenox,order_number:'LENOX-ponum',vendor:@vendor)
      @order.update_custom_value!(@cdefs[:order_destination_code],'HG')
      @order.update_custom_value!(@cdefs[:order_factory_code],'0000007')
      @order_line = Factory(:order_line,order:@order,product:@product,quantity:100,price_per_unit:100.25)
      @order_line.update_custom_value!(@cdefs[:order_line_destination_code],'HDC')
      @container = Factory(:container,entry:@entry,container_number:'CN1',container_size:'40',
        weight:50,fcl_lcl:'F',quantity:23,seal_number:'SN')

    end

    
    describe :find_entries do
      before :each do
        @bvr = Factory(:business_validation_result)
        @entry = Factory(:entry,importer:@lenox,entry_filed_date:1.day.ago)
        @bvr.validatable = @entry
        @bvr.state = 'Pass'
        @bvr.save!
      end
      it "should find entries" do
        expect(described_class.new.find_entries.to_a).to eq [@entry]
      end
      it "should not find entries not for lenox" do
        @entry.importer = Factory(:importer)
        @entry.save!
        expect(described_class.new.find_entries.to_a).to be_empty
      end
      it "should not find entries where business rules are not passed" do
        @bvr.state = 'Skipped'
        @bvr.save!
        expect(described_class.new.find_entries.to_a).to be_empty
      end
      it "should not find entries not filed" do
        @entry.update_attributes(entry_filed_date:nil)
        expect(described_class.new.find_entries.to_a).to be_empty
      end
      it "should not find entries that have been sent before" do
        @entry.sync_records.create!(trading_partner:described_class::SYNC_CODE,
          sent_at:1.hour.ago,confirmed_at:1.minute.ago)
        expect(described_class.new.find_entries.to_a).to be_empty
      end
    end
    describe :generate_header_rows do
      
      it "should make header row" do
        r = []
        described_class.new.generate_header_rows @entry do |row|
          r << row
        end
        expect(r.size).to eq 1
        row = r.first
        expect(row[0,4]).to eq 'ASNH'
        expect(row[4,35].rstrip).to eq @entry.master_bills_of_lading
        expect(row[39,8].rstrip).to eq 'VENCODE'
        expect(row[47,17].rstrip).to eq 'CN1'
        expect(row[64,10].rstrip).to eq '40'
        expect(row[74,10]).to eq '0000099000' #weight
        expect(row[84,10].rstrip).to eq 'KG'
        expect(row[94,7]).to eq '0000000' #placeholder for CBMs
        expect(row[101,18].rstrip).to eq 'VES'
        expect(row[119]).to eq 'Y' #fcl flag
        expect(row[120,7]).to eq '0000023' #carton count
        expect(row[127,35].rstrip).to eq 'SN'
        expect(row[162,25].rstrip).to eq '11312345678'
        expect(row[187,20].rstrip).to eq 'P14010337'
        expect(row[207,16].rstrip).to eq '' #placeholder for exfactory & gate in dates
        expect(row[223,8]).to eq '20140116' 
        expect(row[231,10].rstrip).to eq '12345'
        expect(row[241,10].rstrip).to eq '4321'
        expect(row[251,6].rstrip).to eq '11' #placeholder for mode
        expect(row[257,10].rstrip).to eq 'HDC'
        expect(row[267,4]).to eq 'APP '
        expect(row[271,80]).to eq ''.ljust(80)
        expect(row[351,14]).to match /#{Time.now.strftime('%Y%m%d%H%M')}\d{2}/ #Time.now YYYYMMDDHHMMSS
        expect(row[365,15].rstrip).to eq 'vanvendortest'

        expect(row.size).to eq 380
      end
      it "should use different fields for air shipments" do
        @entry.house_bills_of_lading = 'HBOL'
        @entry.transport_mode_code = 40
        @entry.total_packages = 23
        @entry.save!
        r = []
        described_class.new.generate_header_rows @entry do |row|
          r << row
        end
        row = r.first
        expect(row[47,17].rstrip).to eq 'HBOL'
        expect(row[64,10].rstrip).to eq '' #container size
        expect(row[119]).to eq 'N'
        expect(row[120,7]).to eq '0000023'
        expect(row[127,35].rstrip).to eq ''
      end
      it "should set fcl_lcl to N for mode 10" do
        @entry.transport_mode_code = 10
        @entry.save!
        r = []
        described_class.new.generate_header_rows @entry do |row|
          r << row
        end
        row = r.first
        expect(row[119]).to eq 'N'
      end
      it "should send house bill instead of master for mode 10" do
        @entry.transport_mode_code = '10'
        @entry.house_bills_of_lading = 'HBOL'
        @entry.save!
        r = []
        described_class.new.generate_header_rows @entry do |row|
          r << row
        end
        row = r.first
        expect(row[4,35].rstrip).to eq @entry.house_bills_of_lading
      end
      it "should make multiple headers for multiple vendors" do
        v2 = Factory(:company,system_code:'LENOX-V2')
        o2 = Factory(:order,importer:@lenox,order_number:'LENOX-o2',vendor:v2)
        ci_line2 = Factory(:commercial_invoice_line,po_number:'o2',commercial_invoice:Factory(:commercial_invoice,entry:@entry))
        cv = @order.order_lines.first.get_custom_value(@cdefs[:order_destination_code])
        cv.value = 'HDC'
        cv.save!
        r = []
        described_class.new.generate_header_rows @entry do |row|
          r << row
        end
        expect(r.size).to eq 2
        expect(r.last[39,8].rstrip).to eq 'V2'
      end
      it "should raise exception for multiple containers" do
        #THIS IS TEMPORARY UNTIL WE CAN PROPERLY ALLOCATE THE CARTONS FROM THE CONTAINERS FROM IES
        Factory(:container,entry:@entry)
        expect{described_class.new.generate_header_rows(@entry) {|r|}}.
          to raise_error described_class::LenoxBusinessLogicError
      end
      it "should raise exception if order not found for po_number" do
        ci_line2 = Factory(:commercial_invoice_line,po_number:'o2',commercial_invoice:Factory(:commercial_invoice,entry:@entry))
        expect{described_class.new.generate_header_rows(@entry) {|r|}}.
          to raise_error described_class::LenoxBusinessLogicError
      end
      it "should total the gross weight per vendor" do
        v2 = Factory(:company,system_code:'LENOX-V2')
        o2 = Factory(:order,importer:@lenox,order_number:'LENOX-o2',vendor:v2)
        cv = @order.get_custom_value(@cdefs[:order_destination_code])
        cv.value = 'HG'
        cv.save!
        ci_line2 = Factory(:commercial_invoice_line,po_number:'o2',
          commercial_invoice:Factory(:commercial_invoice,entry:@entry,gross_weight:88))
        ci_line2 = Factory(:commercial_invoice_line,po_number:'o2',
          commercial_invoice:Factory(:commercial_invoice,entry:@entry,gross_weight:12))
        r = []
        described_class.new.generate_header_rows @entry do |row|
          r << row
        end
        expect(r.size).to eq 2
        expect(r[0][74,10]).to eq '0000099000'
        expect(r[1][74,10]).to eq '0000100000'      
      end
    end
    describe :generate_detail_rows do
      it "should make detail row" do
        r = []
        described_class.new.generate_detail_rows(@entry) do |dr|
          r << dr
        end
        expect(r.size).to eq 1
        row = r.first
        expect(row[0,4]).to eq 'ASND'
        expect(row[4,35].rstrip).to eq 'MBOL'
        expect(row[39,17].rstrip).to eq 'CN1'
        expect(row[56,10]).to eq '0000000001'
        expect(row[66,10].rstrip).to eq '0000007'
        expect(row[76,35].rstrip).to eq 'ponum'
        expect(row[111,35].rstrip).to eq 'partnum'
        expect(row[146,7]).to eq '0000005' #10 units / 2 per set
        expect(row[153,4].rstrip).to eq 'CN'
        expect(row[157,35].rstrip).to eq '123456'
        expect(row[192,10]).to eq '0000000002'
        expect(row[202,8]).to eq '20140317'
        expect(row[210,88]).to eq ''.ljust(88)
        expect(row[298,14]).to match /#{Time.now.strftime('%Y%m%d%H%M')}\d{2}/ #Time.now YYYYMMDDHHMMSS 
        expect(row[312,15].rstrip).to eq 'vanvendortest'
        expect(row[327,18]).to eq '000000000100250000' #100.25 / unit (order)
        expect(row[345,18]).to eq '000000000100100000' #110.10 / unit

        #double check no extra characters
        expect(row.size).to eq 363
      end
      it "should throw exception if part not found" do
        Product.scoped.destroy_all
        expect{described_class.new.generate_detail_rows(@entry) {|r|}}.
          to raise_error described_class::LenoxBusinessLogicError
      end
      it "should default to 1 if no units per set" do
        Product.first.custom_values.destroy_all
        r = []
        described_class.new.generate_detail_rows(@entry) do |dr|
          r << dr
        end
        row = r.first
        expect(row[146,7]).to eq '0000010' #10 units / 1 per set
      end
      it "should not duplicate rows for multiple order lines" do
        @order_line = Factory(:order_line,order:@order,product:@product,quantity:100,price_per_unit:100.25)
        r = []
        expect {
          described_class.new.generate_detail_rows(@entry) do |dr|
            r << dr
          end
        }.to change(r,:size).to(1)
      end
    end
    describe :generate_tempfiles do
      it "should generate compliant files" do
        g = described_class.new
        header_file, detail_file = g.generate_tempfiles [@entry]
        header_rows = []
        g.generate_header_rows(@entry) {|r| header_rows << r} 
        detail_rows = []
        g.generate_detail_rows(@entry) {|r| detail_rows << r}
        expect(IO.read(header_file.path)).to eq "#{header_rows.first}\n"
        expect(IO.read(detail_file.path)).to eq "#{detail_rows.first}\n" 
      end
      it "should write sync records" do
        expect {
          described_class.new.generate_tempfiles [@entry]
        }.to change(
          SyncRecord.where(syncable_id:@entry.id,
            trading_partner:'LENOXASN').
          where('confirmed_at is not null'),:count).from(0).to(1)
      end
    end
  end
end
