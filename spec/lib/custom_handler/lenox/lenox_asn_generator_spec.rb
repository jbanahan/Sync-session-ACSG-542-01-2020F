describe OpenChain::CustomHandler::Lenox::LenoxAsnGenerator do
  describe "run_schedulable" do
    it "should ftp_file" do
      ents = 'x'
      files = ['y', 'z']
      sync_record = SyncRecord.new trading_partner: "Test"
      expect_any_instance_of(described_class).to receive(:find_shipments).and_return(ents)
      expect_any_instance_of(described_class).to receive(:generate_tempfiles).with(ents).and_yield(files[0], files[1], [sync_record])
      expect_any_instance_of(described_class).to receive(:ftp_sync_file).with(files[0], [sync_record], {remote_file_name:'Vand_Header'})
      expect_any_instance_of(described_class).to receive(:ftp_file).with(files[1], {remote_file_name:'Vand_Detail'})
      described_class.run_schedulable
      expect(sync_record.persisted?).to eq true
    end
  end

  describe "ftp_credentials" do
    it "should generate base non-production credentials" do
      exp = {:server=>'ftp.lenox.com', :username=>'vanvendortest', :password=>'$hipments', :folder=>"."}
      found = described_class.new.ftp_credentials
      expect(found[:server]).to eq exp[:server]
      expect(found[:username]).to eq exp[:username]
      expect(found[:password]).to eq exp[:password]
    end
    it "should generate base production credentials" do
      exp = {:server=>'ftp.lenox.com', :username=>'vanvendor', :password=>'$hipments', :folder=>"."}
      found = described_class.new('env'=>'production').ftp_credentials
      expect(found[:server]).to eq exp[:server]
      expect(found[:username]).to eq exp[:username]
      expect(found[:password]).to eq exp[:password]
    end
  end

  context "needs_data" do
    before :each do
      @cdefs = described_class.prep_custom_definitions [:ord_factory_code, :ord_destination_code, :prod_country_of_origin, :ord_line_destination_code]
      @lenox = create(:company, alliance_customer_number:'LENOX', system_code:'LENOX')
      @vendor = create(:company, system_code:'LENOX-VENCODE')
      @product = create(:product, importer:@lenox, unique_identifier:'LENOX-partnum')
      @product.update_custom_value!(@cdefs[:prod_country_of_origin], 'CN')
      @order = create(:order, importer:@lenox, order_number:'LENOX-ponum', vendor:@vendor, customer_order_number:'ponum')
      @order.update_custom_value!(@cdefs[:ord_destination_code], 'HG')
      @order.update_custom_value!(@cdefs[:ord_factory_code], '0000007')
      # @product.update_custom_value!(@cdefs[:product_units_per_set],2)
      @order_line = create(:order_line, order:@order, product:@product, quantity:100, price_per_unit:100.10)
      @order_line.update_custom_value!(@cdefs[:ord_line_destination_code], 'HDC')
      @shipment = create(:shipment, importer:@lenox, house_bill_of_lading:'HBOL',
        vessel:'VES', est_departure_date:Date.new(2014, 7, 1),
        unlading_port:create(:port, schedule_d_code:'4321'),
        lading_port:create(:port, schedule_k_code:'12345'),
        )
      @con = @shipment.containers.create!(container_size:"GP40'", container_number:'CN1', seal_number:'SN')
      @shipment_line = @shipment.shipment_lines.build(product_id:@product.id, quantity:10, gross_kgs:50, cbms:70, line_number:2, carton_qty:23)
      @shipment_line.container = @con
      @shipment_line.linked_order_line_id = @order_line.id
      @shipment_line.save!

=begin
      @entry = create(:entry,importer:@lenox,master_bills_of_lading:'MBOL',entry_number:'11312345678',
        vessel:'VES',customer_references:'P14010337',export_date:Date.new(2014,7,1),
        lading_port_code:'12345',unlading_port_code:'4321',transport_mode_code:'11',container_sizes:'40',broker_invoice_total:1)
      @ci = create(:commercial_invoice,entry:@entry,gross_weight:99,invoice_number:'123456',invoice_date:Date.new(2014,3,17))
      @ci_line = create(:commercial_invoice_line,commercial_invoice:@ci,po_number:'ponum',
        quantity:10, country_origin_code:'CN',part_number:'partnum',unit_price:100.10,line_number:2
      )
      @container = create(:container,entry:@entry,container_number:'CN1',container_size:'40',
        weight:50,fcl_lcl:'F',quantity:23,seal_number:'SN')
=end
    end


    describe "find_shipments" do
      it "should find shipment" do
        expect(described_class.new.find_shipments.to_a).to eq [@shipment]
      end
      it "should not find entries not for lenox" do
        @shipment.importer = create(:importer)
        @shipment.save!
        expect(described_class.new.find_shipments.to_a).to be_empty
      end
      it "should not find entries that have been sent before" do
        @shipment.sync_records.create!(trading_partner:described_class::SYNC_CODE,
          sent_at:1.hour.ago, confirmed_at:1.minute.ago)
        expect(described_class.new.find_shipments.to_a).to be_empty
      end
    end
    describe "generate_header_rows" do
      it "should make header row" do
        r = []
        described_class.new.generate_header_rows @shipment do |row|
          r << row
        end
        expect(r.size).to eq 1
        row = r.first
        expect(row[0, 4]).to eq 'ASNH'
        expect(row[4, 35].rstrip).to eq @shipment.house_bill_of_lading
        expect(row[39, 8].rstrip).to eq 'VENCODE'
        expect(row[47, 17].rstrip).to eq 'CN1'
        expect(row[64, 10].rstrip).to eq '40'
        expect(row[74, 10]).to eq '0000050000' # weight
        expect(row[84, 10].rstrip).to eq 'KG'
        expect(row[94, 7]).to eq '0070000' # CBMs
        expect(row[101, 18].rstrip).to eq 'VES'
        expect(row[119]).to eq 'Y' # fcl flag
        expect(row[120, 7]).to eq '0000023' # carton count
        expect(row[127, 35].rstrip).to eq 'SN'
        expect(row[162, 25].rstrip).to eq ''
        expect(row[187, 20].rstrip).to eq ''
        expect(row[207, 16].rstrip).to eq '' # placeholder for exfactory & gate in dates
        expect(row[223, 8]).to eq '20140701'
        expect(row[231, 10].rstrip).to eq '12345'
        expect(row[241, 10].rstrip).to eq '4321'
        expect(row[251, 6].rstrip).to eq '11' # placeholder for mode
        expect(row[257, 10].rstrip).to eq 'HDC'
        expect(row[267, 4]).to eq 'APP '
        expect(row[271, 80]).to eq ''.ljust(80)
        expect(row[351, 14]).to match /#{ActiveSupport::TimeZone["UTC"].now.strftime('%Y%m%d%H%M')}\d{2}/ # Time.now YYYYMMDDHHMMSS
        expect(row[365, 15].rstrip).to eq 'vanvendortest'

        expect(row.size).to eq 380
      end
      it "should make all 45 containers into 45HC" do
        @con.update_attributes(container_size:'HQ45\'')
        r = []
        described_class.new.generate_header_rows @shipment do |row|
          r << row
        end
        expect(r.first[64, 10].rstrip).to eq '45HC'
      end
      it "should set fcl_lcl to N for container_sizes LCL" do
        @shipment_line.update_attributes(cbms:1)
        r = []
        described_class.new.generate_header_rows @shipment do |row|
          r << row
        end
        row = r.first
        expect(row[119]).to eq 'N'
      end
      it "does not bomb if ports are missing" do
        @shipment.update_attributes! lading_port: nil, unlading_port: nil
        r = []
        described_class.new.generate_header_rows @shipment do |row|
          r << row
        end
        expect(r.size).to eq 1
        row = r[0]
        expect(row[231, 10].rstrip).to eq ''
        expect(row[241, 10].rstrip).to eq ''
      end
    end
    describe "generate_detail_rows" do
      it "should make detail row" do
        r = []
        described_class.new.generate_detail_rows(@shipment) do |dr|
          r << dr
        end
        expect(r.size).to eq 1
        row = r.first
        expect(row[0, 4]).to eq 'ASND'
        expect(row[4, 35].rstrip).to eq 'HBOL'
        expect(row[39, 17].rstrip).to eq 'CN1'
        expect(row[56, 10]).to eq '0000000001'
        expect(row[66, 10].rstrip).to eq '0000007'
        expect(row[76, 35].rstrip).to eq 'ponum'
        expect(row[111, 35].rstrip).to eq 'partnum'
        expect(row[146, 7]).to eq '0000010' # unites
        expect(row[153, 4].rstrip).to eq 'CN'
        expect(row[157, 35].rstrip).to eq '' # invoice number
        expect(row[192, 10]).to eq '0000000002'
        expect(row[202, 8].strip).to eq '' # invoice date
        expect(row[210, 88]).to eq ''.ljust(88)
        expect(row[298, 14]).to match /#{ActiveSupport::TimeZone["UTC"].now.strftime('%Y%m%d%H%M')}\d{2}/ # Time.now YYYYMMDDHHMMSS
        expect(row[312, 15].rstrip).to eq 'vanvendortest'
        expect(row[327, 18]).to eq '000000000100100000' # 100.10 / unit
        expect(row[345, 18]).to eq '000000000100100000' # 100.10 / unit
        expect(row[363, 8].rstrip).to eq 'VENCODE'


        # double check no extra characters
        expect(row.size).to eq 371
      end
      it "should default to 1 if no units per set" do
        Product.first.custom_values.destroy_all
        r = []
        described_class.new.generate_detail_rows(@shipment) do |dr|
          r << dr
        end
        row = r.first
        expect(row[146, 7]).to eq '0000010' # 10 units / 1 per set
      end

      it "handles casing differences in unique identifier" do
        @product.update_attributes! unique_identifier: "LeNoX-partnum"
        r = []
        subject.generate_detail_rows @shipment do |row|
          r << row
        end
        expect(r.size).to eq 1
        row = r.first
        expect(row[111, 35].rstrip).to eq 'partnum'
      end
    end
    describe "generate_tempfiles" do
      it "should generate compliant files" do
        g = described_class.new
        expect(g).to receive(:generate_header_rows).with(@shipment).and_yield("abc")
        expect(g).to receive(:generate_detail_rows).with(@shipment).and_yield("xyz")
        header_file = nil
        detail_file = nil
        g.generate_tempfiles([@shipment]) do |f1, f2|
          header_file = f1.read
          detail_file = f2.read
        end
        expect(header_file).to eq "abc\n"
        expect(detail_file).to eq "xyz\n"
      end
      it "should write sync records" do
        g = described_class.new
        allow(g).to receive(:generate_header_rows)
        allow(g).to receive(:generate_detail_rows)
        sync_records = []

        expect {
          g.generate_tempfiles([@shipment]) {|f1, f2, srs| sync_records = srs}
        }.to change(
          SyncRecord.where(syncable_id:@shipment.id,
            trading_partner:'LENOXASN').
          where('confirmed_at is not null'), :count).from(0).to(1)

        expect(sync_records.length).to eq 1
        expect(sync_records.first).to eq @shipment.sync_records.first
      end
    end
  end
end
