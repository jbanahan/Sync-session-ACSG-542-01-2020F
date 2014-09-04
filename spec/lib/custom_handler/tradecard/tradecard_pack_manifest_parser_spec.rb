require 'spec_helper'

describe OpenChain::CustomHandler::Tradecard::TradecardPackManifestParser do
  describe :process_attachment do
    it "should get path and call parse" do
      u = double(:user)
      s = double(:shipment)
      att = double(:attachment)
      atchd = double(:attached)
      att.should_receive(:attached).and_return atchd
      path = 'xyz'
      atchd.should_receive(:path).and_return path
      described_class.should_receive(:parse).with(s,path,u).and_return 'x'
      expect(described_class.process_attachment(s, att, u)).to eq 'x'
    end
  end
  describe :parse do
    it "should create object and call run" do
      s = double('shipment')
      path = double('data')
      x = double('xlclient')
      u = double('user')
      OpenChain::XLClient.should_receive(:new).with(path).and_return x      
      t = double('x')
      described_class.should_receive(:new).and_return t
      t.should_receive(:run).with(s,x,u)
      described_class.parse s, path, u
    end
  end

  describe :run do
    it "should process_rows" do
      x = double('xlclient')
      s = double('shipment')
      u = double('user')
      r = double('rows')
      x.should_receive(:all_row_values).and_return r
      d = described_class.new
      d.should_receive(:process_rows).with(s,r,u)
      d.run(s,x,u)
    end
  end
  describe "process_rows" do
    def init_mock_array total_rows, row_values_hash
      r = Array.new(total_rows,[])
      #always set cell B2 to 'Packing Manifest'
      r[1] = ['','Packing Manifest']
      r
      row_values_hash.each do |k,v|
        r[k] = v
      end
      r
    end
    def mode_row mode
      ['','','','','Method','','','','','','',mode]
    end
    def subtitle_row subtitle
      ['',subtitle]
    end
    def detail_line overrides
      base = {range:'0001',
        carton_start:'1234500',
        carton_end:'1234502',
        po:'ORD',
        sku:'SK',
        item_qty:'60',
        carton_qty:'3',
        net_net:'6.600',
        net:'6.800',
        gross:'7.000',
        weight_unit:'KG',
        length:'24.000',
        width:'15.000',
        height:'9.000',
        dim_unit:'CM'
      }.merge overrides 
      r = Array.new(57,'')
      r[5] = base[:range]
      r[6] = base[:carton_start]
      r[9] = base[:carton_end]
      r[14] = base[:po]
      r[20] = base[:sku]
      r[29] = base[:item_qty]
      r[37] = base[:carton_qty]
      r[42] = base[:net_net]
      r[45] = base[:net]
      r[47] = base[:gross]
      r[48] = base[:weight_unit]
      r[49] = base[:length]
      r[51] = base[:width]
      r[53] = base[:height]
      r[55] = base[:dim_unit]
      r
    end

    before :each do
      @s = Factory(:shipment)
      @u = Factory(:user)
      @s.stub(:can_edit?).and_return true
    end
    it "should error if cell B2 doesn't say 'Packing Manifest'" do
      r = init_mock_array 3, {1=>['','']}
      expect{described_class.new.process_rows(@s,r,@u)}.to raise_error "INVALID FORMAT: Cell B2 must contain 'Packing Manifest'."
    end
    it "should error if user cannot edit shipment" do
      @s.stub(:can_edit?).and_return false
      expect{described_class.new.process_rows(@s,init_mock_array(3,{}),@u)}.to raise_error "You do not have permission to edit this shipment."
    end
    it "should add containers for ocean" do
      row_seed = {61=>mode_row('OCEAN'),
        76=>subtitle_row('EQUIPMENT SUMMARY'),
        77=>['','','','Equipment #','Item Qty'],
        78=>['','','','ABCD12345','1234','10',''], #only care about the container number
        79=>['','','','Totals']
      }
      rows = init_mock_array 80, row_seed
      expect{described_class.new.process_rows(@s,rows,@u)}.to change(Container,:count).from(0).to(1)
      @s.reload
      expect(@s.containers.first.container_number).to eq 'ABCD12345'
    end
    it "should not duplicate containers" do
      @s.containers.create!(container_number:'ABCD12345')
      row_seed = {61=>mode_row('OCEAN'),
        76=>subtitle_row('EQUIPMENT SUMMARY'),
        77=>['','','','Equipment #','Item Qty'],
        78=>['','','','ABCD12345','1234','10',''], #only care about the container number
        79=>['','','','Totals']
      }
      rows = init_mock_array 80, row_seed
      expect{described_class.new.process_rows(@s,rows,@u)}.to_not change(Container,:count)
    end
    it "should ignore equipment for non-ocean" do
      row_seed = {61=>mode_row('AIR'),
        76=>subtitle_row('EQUIPMENT SUMMARY'),
        77=>['','','','Equipment #','Item Qty'],
        78=>['','','','ABCD12345','1234','10',''], #only care about the container number
        79=>['','','','Totals']
      }
      rows = init_mock_array 80, row_seed
      expect{described_class.new.process_rows(@s,rows,@u)}.to_not change(Container,:count)
    end
    it "should add lines" do
      c = Factory(:company)
      p = Factory(:product)
      o = Factory(:order,importer:c,customer_order_number:'ordnum')
      ol = Factory(:order_line,quantity:100,product:p,sku:'sk12345',order:o)
      ol2 = Factory(:order_line,quantity:100,product:p,sku:'sk55555',order:o)
      @s.update_attributes(importer_id:c.id)
      row_seed = {
        82=>subtitle_row('CARTON DETAIL'),
        84=>['','','','Equipment#: WHATEVER'],
        85=>['','','','','Range'],
        86=>detail_line({po:'ordnum',sku:'sk12345',item_qty:'8'}),
        87=>detail_line({po:'ordnum',sku:'sk55555',item_qty:'5'})
      }
      rows = init_mock_array 90, row_seed
      expect{described_class.new.process_rows(@s,rows,@u)}.to change(ShipmentLine,:count).from(0).to(2)
      @s.reload
      f = @s.shipment_lines.first
      expect(f.product).to eq p
      expect(f.quantity).to eq 8
      expect(f.order_lines.to_a).to eq [ol]
      expect(f.line_number).to eq 1
      l = @s.shipment_lines.last
      expect(l.product).to eq p
      expect(l.quantity).to eq 5
      expect(l.order_lines.to_a).to eq [ol2]
      expect(l.line_number).to eq 2
    end
    it "should handle commas in quantity" do
      c = Factory(:company)
      p = Factory(:product)
      o = Factory(:order,importer:c,customer_order_number:'ordnum')
      ol = Factory(:order_line,quantity:100,product:p,sku:'sk12345',order:o)
      @s.update_attributes(importer_id:c.id)
      row_seed = {
        82=>subtitle_row('CARTON DETAIL'),
        84=>['','','','Equipment#: WHATEVER'],
        85=>['','','','','Range'],
        86=>detail_line({po:'ordnum',sku:'sk12345',item_qty:'8,000'}),
      }
      rows = init_mock_array 90, row_seed
      expect{described_class.new.process_rows(@s,rows,@u)}.to change(ShipmentLine,:count).from(0).to(1)
      @s.reload
      f = @s.shipment_lines.first
      expect(f.product).to eq p
      expect(f.quantity).to eq 8000
      expect(f.order_lines.to_a).to eq [ol]
    end
    it "should not add lines for a different importer" do
      c = Factory(:company)
      p = Factory(:product)
      o = Factory(:order,importer:c,customer_order_number:'ordnum')
      ol = Factory(:order_line,quantity:100,product:p,sku:'sk12345',order:o)
      @s.update_attributes(importer_id:Factory(:company).id)
      row_seed = {
        82=>subtitle_row('CARTON DETAIL'),
        84=>['','','','Equipment#: WHATEVER'],
        85=>['','','','','Range'],
        86=>detail_line({po:'ordnum',sku:'sk12345',item_qty:'8'}),
      }
      rows = init_mock_array 90, row_seed
      expect{described_class.new.process_rows(@s,rows,@u)}.to raise_error "Order Number ordnum not found."
    end
    it "should assign lines to container" do
      c = Factory(:company)
      p = Factory(:product)
      o = Factory(:order,importer:c,customer_order_number:'ordnum')
      ol = Factory(:order_line,quantity:100,product:p,sku:'sk12345',order:o)
      @s.update_attributes(importer_id:c.id)
      row_seed = {61=>mode_row('OCEAN'),
        76=>subtitle_row('EQUIPMENT SUMMARY'),
        77=>['','','','Equipment #','Item Qty'],
        78=>['','','','ABCD12345','1234','10',''], #only care about the container number
        79=>['','','','Totals'],
        82=>subtitle_row('CARTON DETAIL'),
        84=>['','','','Equipment#: ABCD12345 Type:123 Seal: DEF'],
        85=>['','','','','Range'],
        86=>detail_line({po:'ordnum',sku:'sk12345',item_qty:'8'}),
      }
      rows = init_mock_array 90, row_seed
      described_class.new.process_rows(@s,rows,@u)
      @s.reload
      expect(@s.shipment_lines.first.container.container_number).to eq 'ABCD12345'
    end
    it "should handle blank line between EQUIPMENT SUMMARY and container table" do
      c = Factory(:company)
      p = Factory(:product)
      o = Factory(:order,importer:c,customer_order_number:'ordnum')
      ol = Factory(:order_line,quantity:100,product:p,sku:'sk12345',order:o)
      @s.update_attributes(importer_id:c.id)
      row_seed = {61=>mode_row('OCEAN'),
        76=>subtitle_row('EQUIPMENT SUMMARY'),
        77=>['','','',''],
        78=>['','','','Equipment #','Item Qty'],
        79=>['','','','ABCD12345','1234','10',''], #only care about the container number
        80=>['','','','Totals'],
        83=>subtitle_row('CARTON DETAIL'),
        85=>['','','','Equipment#: ABCD12345 Type:123 Seal: DEF'],
        86=>['','','','','Range'],
        87=>detail_line({po:'ordnum',sku:'sk12345',item_qty:'8'}),
      }
      rows = init_mock_array 90, row_seed
      described_class.new.process_rows(@s,rows,@u)
      @s.reload
      expect(@s.shipment_lines.first.container.container_number).to eq 'ABCD12345'
      
    end
    it "should fail on missing PO" do
      row_seed = {
        82=>subtitle_row('CARTON DETAIL'),
        84=>['','','','Equipment#: WHATEVER'],
        85=>['','','','','Range'],
        86=>detail_line({po:'ordnum',sku:'sk12345',item_qty:'8'}),
      }
      rows = init_mock_array 90, row_seed
      expect{described_class.new.process_rows(@s,rows,@u)}.to raise_error "Order Number ordnum not found."
    end
    it "should fail on missing SKU" do
      c = Factory(:company)
      o = Factory(:order,importer:c,customer_order_number:'ordnum')
      @s.update_attributes(importer_id:c.id)
      row_seed = {
        82=>subtitle_row('CARTON DETAIL'),
        84=>['','','','Equipment#: WHATEVER'],
        85=>['','','','','Range'],
        86=>detail_line({po:'ordnum',sku:'sk12345',item_qty:'8'}),
      }
      rows = init_mock_array 90, row_seed
      expect{described_class.new.process_rows(@s,rows,@u)}.to raise_error "SKU sk12345 not found in order ordnum (ID: #{o.id})."
    end
    it "should rollback changes on error" do
      c = Factory(:company)
      o = Factory(:order,importer:c,customer_order_number:'ordnum')
      @s.update_attributes(importer_id:c.id)
      row_seed = {
        61=>mode_row('OCEAN'),
        76=>subtitle_row('EQUIPMENT SUMMARY'),
        77=>['','','','Equipment #','Item Qty'],
        78=>['','','','ABCD12345','1234','10',''],
        79=>['','','','Totals'],
        82=>subtitle_row('CARTON DETAIL'),
        84=>['','','','Equipment#: WHATEVER'],
        85=>['','','','','Range'],
        86=>detail_line({po:'ordnum',sku:'sk12345',item_qty:'8'})
      }
      rows = init_mock_array 90, row_seed
      expect{described_class.new.process_rows(@s,rows,@u)}.to raise_error
      @s.reload
      expect(@s.containers).to be_empty
    end
    context :cartons do
      before :each do
        c = Factory(:company)
        p = Factory(:product)
        o = Factory(:order,importer:c,customer_order_number:'ORD')
        ol = Factory(:order_line,quantity:100,product:p,sku:'SK',order:o)
        @s.update_attributes(importer_id:c.id)
      end
      it "should add carton ranges" do
        row_seed = {
          82=>subtitle_row('CARTON DETAIL'),
          84=>['','','','Equipment#: WHATEVER'],
          85=>['','','','','Range'],
          86=>detail_line({range:'0001',carton_start:'1100',carton_qty:'2',item_qty:'10'}),
          87=>detail_line({range:'0002',carton_start:'1102',carton_qty:'4',item_qty:'8'})
        }
        rows = init_mock_array 90, row_seed
        expect{described_class.new.process_rows(@s,rows,@u)}.to change(CartonSet,:count).from(0).to(2)
        @s.reload
        cs = @s.carton_sets.find_by_starting_carton('1100')
        expect(cs.carton_qty).to eq 2
        expect(cs.length_cm).to eq 24
        expect(cs.width_cm).to eq 15
        expect(cs.height_cm).to eq 9
        expect(cs.net_net_kgs).to eq 6.6
        expect(cs.net_kgs).to eq 6.8
        expect(cs.gross_kgs).to eq 7
        expect(cs.shipment_lines.count).to eq 1
        expect(cs.shipment_lines.first).to eq @s.shipment_lines.first
        expect(@s.shipment_lines.count).to eq 2
      end
      it "should convert IN to CM" do
        row_seed = {
          82=>subtitle_row('CARTON DETAIL'),
          84=>['','','','Equipment#: WHATEVER'],
          85=>['','','','','Range'],
          86=>detail_line({range:'0001',carton_start:'1100',carton_qty:'2',item_qty:'10',dim_unit:'IN',length:'1',width:'1',height:'1'}),
        }
        rows = init_mock_array 90, row_seed
        expect{described_class.new.process_rows(@s,rows,@u)}.to change(CartonSet,:count).from(0).to(1)
        @s.reload
        cs = @s.carton_sets.first
        expect(cs.length_cm).to eq 2.54
        expect(cs.width_cm).to eq 2.54
        expect(cs.height_cm).to eq 2.54
      end
      it "should convert LB to KG" do
        row_seed = {
          82=>subtitle_row('CARTON DETAIL'),
          84=>['','','','Equipment#: WHATEVER'],
          85=>['','','','','Range'],
          86=>detail_line({range:'0001',carton_start:'1100',carton_qty:'2',item_qty:'10',weight_unit:'LB',net:'2.20462'}),
        }
        rows = init_mock_array 90, row_seed
        expect{described_class.new.process_rows(@s,rows,@u)}.to change(CartonSet,:count).from(0).to(1)
        @s.reload
        cs = @s.carton_sets.first
        expect(cs.net_kgs).to eq 1
      end
      it "should assign line w/ blank carton range to the last carton range" do
        row_seed = {
          82=>subtitle_row('CARTON DETAIL'),
          84=>['','','','Equipment#: WHATEVER'],
          85=>['','','','','Range'],
          86=>detail_line({range:'0001',carton_start:'1100',carton_qty:'2',item_qty:'10'}),
          87=>detail_line({range:'',carton_start:'',carton_qty:'',item_qty:'10'}),
          88=>detail_line({range:'0002',carton_start:'1102',carton_qty:'2',item_qty:'10'}),
        }
        rows = init_mock_array 90, row_seed
        expect{described_class.new.process_rows(@s,rows,@u)}.to change(CartonSet,:count).from(0).to(2)
        @s.reload
        expect(@s.shipment_lines.count).to eq 3
        cs_from_shipment_lines = @s.shipment_lines.collect {|sl| sl.carton_set}
        first_cs = @s.carton_sets.first
        last_cs = @s.carton_sets.last
        expect(cs_from_shipment_lines).to eq [first_cs, first_cs, last_cs]

      end

    end
  end
end