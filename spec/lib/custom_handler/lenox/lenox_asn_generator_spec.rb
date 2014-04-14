require 'spec_helper'

describe OpenChain::CustomHandler::Lenox::LenoxAsnGenerator do
  before :each do 
    @cdefs = described_class.prep_custom_definitions described_class::CUSTOM_DEFINITION_INSTRUCTIONS.keys
    @lenox = Factory(:company,alliance_customer_number:'LENOX',system_code:'LENOX')
    @vendor = Factory(:company,system_code:'LENOX-VENCODE')
    @entry = Factory(:entry,importer:@lenox,master_bills_of_lading:'MBOL',entry_number:'11312345678',
      vessel:'VES',customer_references:'P14010337',export_date:Date.new(2014,1,16),
      lading_port_code:'12345',unlading_port_code:'4321',transport_mode_code:'11')
    @ci = Factory(:commercial_invoice,entry:@entry,gross_weight:99)
    @ci_line = Factory(:commercial_invoice_line,commercial_invoice:@ci,po_number:'ponum',
      quantity:10, country_origin_code:'CN',part_number:'partnum'
    )
    @product = Factory(:product,importer:@lenox,unique_identifier:'LENOX-partnum')
    @product.update_custom_value!(@cdefs[:product_units_per_set],2)
    @order = Factory(:order,importer:@lenox,order_number:'LENOX-ponum',vendor:@vendor)
    @order.update_custom_value!(@cdefs[:order_destination_code],'HG')
    @order.update_custom_value!(@cdefs[:order_factory_code],'0000007')
    @container = Factory(:container,entry:@entry,container_number:'CN1',container_size:'40',
      weight:50,fcl_lcl:'F',quantity:23,seal_number:'SN')

  end

  describe :run_schedulable do
    it "should email on LenoxBusinessLogicError"
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
      expect(row[251,5].rstrip).to eq '11'
      expect(row[256,10].rstrip).to eq 'HG'
      expect(row[266,4]).to eq 'APP '
      expect(row[270,80]).to eq ''.ljust(80)
      expect(row[350,14]).to match /#{Time.now.strftime('%Y%m%d%H%M')}\d{2}/ #Time.now YYYYMMDDHHMMSS
      expect(row[364,15].rstrip).to eq 'vanvendortest'

      expect(row.size).to eq 379
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
    it "should make multiple headers for multiple vendors" do
      v2 = Factory(:company,system_code:'LENOX-V2')
      o2 = Factory(:order,importer:@lenox,order_number:'LENOX-o2',vendor:v2)
      cv = @order.get_custom_value(@cdefs[:order_destination_code])
      cv.value = 'HG'
      cv.save!
      ci_line2 = Factory(:commercial_invoice_line,po_number:'o2',commercial_invoice:Factory(:commercial_invoice,entry:@entry))
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
      expect(row.size).to eq 311
      expect(row[0,4]).to eq 'ASND'
      expect(row[4,35].rstrip).to eq 'MBOL'
      expect(row[39,17].rstrip).to eq 'CN1'
      expect(row[56,9]).to eq '000000001'
      expect(row[65,10].rstrip).to eq '0000007'
      expect(row[75,35].rstrip).to eq 'ponum'
      expect(row[110,35].rstrip).to eq 'partnum'
      expect(row[145,7]).to eq '0000005' #10 units / 2 per set
      expect(row[152,4].rstrip).to eq 'CN'
      expect(row[156,126]).to eq ''.ljust(126)
      expect(row[282,14]).to match /#{Time.now.strftime('%Y%m%d%H%M')}\d{2}/ #Time.now YYYYMMDDHHMMSS 
      expect(row[296,15].rstrip).to eq 'vanvendortest'
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
      expect(row[145,7]).to eq '0000010' #10 units / 1 per set
    end
  end
  describe :generate_temp_files do
    it "should generate compliant files" do
      g = described_class.new
      header_file, detail_file = g.generate_temp_files [@entry]
      header_rows = []
      g.generate_header_rows(@entry) {|r| header_rows << r} 
      detail_rows = []
      g.generate_detail_rows(@entry) {|r| detail_rows << r}
      expect(IO.read(header_file.path)).to eq "#{header_rows.first}\n"
      expect(IO.read(detail_file.path)).to eq "#{detail_rows.first}\n" 
    end
  end
end
