require 'spec_helper'

describe OpenChain::CustomHandler::Tradecard::TradecardPackManifestParser do
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
        dim_unit:'IN'
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
      l = @s.shipment_lines.last
      expect(l.product).to eq p
      expect(l.quantity).to eq 5
      expect(l.order_lines.to_a).to eq [ol2]
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
    context :cartons do
      it "should add carton ranges"
      it "should assign lines to carton ranges"
      it "should convert IN to CM"
      it "should convert LB to KG"
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
        86=>detail_line({po:'ordnum',sku:'sk12345',item_qty:'8'}),
      }
      rows = init_mock_array 90, row_seed
      expect{described_class.new.process_rows(@s,rows,@u)}.to raise_error
      @s.reload
      expect(@s.containers).to be_empty
    end
  end
end