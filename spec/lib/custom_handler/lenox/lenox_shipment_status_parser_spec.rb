require 'spec_helper'

describe OpenChain::CustomHandler::Lenox::LenoxShipmentStatusParser do
  def default_row overrides={}
    h = {po:'ORD123',part:'PART',qty:100,pol:'Yantian, China',
      etd:'2014-01-01',
      pod:'Norfolk, Virginia',bol:'OOLU12345678',vessel:'VESS',
      container:'CONT12345678',size:'SZ',gross_weight:'49.2',cartons:4,
      volume:'29.4',seal_number:'SL123',invoice_number:'INV123'}.merge overrides
    r = Array.new 19
    r[3] = h[:po]
    r[4] = h[:part]
    r[5] = h[:qty]
    r[6] = h[:pol]
    r[7] = h[:etd]
    r[8] = h[:pod]
    r[9] = h[:bol]
    r[10] = h[:vessel]
    r[11] = h[:container]
    r[12] = h[:size]
    r[14] = h[:gross_weight]
    r[15] = h[:cartons]
    r[16] = h[:volume]
    r[17] = h[:seal_number]
    r[18] = h[:invoice_number]
    r
  end

  def mock_xl_client rows
    x = double(:xl_client)
    stubbed = x.stub(:all_row_values,0)
    rows.each {|row| stubbed = stubbed.and_yield row}
    x
  end

  describe :process do
    before :each do
      @cf = double(:custom_file)
    end
    it "should initialize XLClient and pass to parse" do
      x = double(:xl_client)
      OpenChain::XLClient.should_receive(:new_from_attachable).with(@cf).and_return x
      described_class.any_instance.should_receive(:parse).with(x)
      described_class.stub(:can_view?).and_return true
      described_class.new(@cf).process User.new
    end
    it "should raise error if user cannot view" do
      u = User.new
      described_class.should_receive(:can_view?).with(u).and_return false
      expect {described_class.new(@cf).process(u) }.to raise_error "Processing Failed because you cannot view this file."
    end
  end

  describe :can_view? do
    before :each do
      @cf = double(:custom_file)
      MasterSetup.any_instance.stub(:custom_feature?).and_return true
    end
    it "should be false if user not from LENOX or master" do
      u = Factory(:user,shipment_view:true)
      expect(described_class.new(@cf).can_view?(u)).to eq false
    end
    it "should be false if user cannot view shipments" do
      u = Factory(:master_user,shipment_view:false)
      expect(described_class.new(@cf).can_view?(u)).to eq false
    end
    it "should pass for master user who can view shipments" do
      u = Factory(:master_user,shipment_view:true)
      expect(described_class.new(@cf).can_view?(u)).to eq true
    end
    it "should pass for lenox user who can view shipments" do
      u = Factory(:user,shipment_view:true,company:Factory(:company,:system_code=>'LENOX'))
      u.stub(:view_shipments?).and_return true
      expect(described_class.new(@cf).can_view?(u)).to eq true
    end
  end

  describe :parse do
    it "should collect shipments and pass them to process_shipment" do
      r1 = default_row
      r2 = default_row({bol:'BOL2'})
      x = mock_xl_client([r1,r2])
      p = described_class.new(double(:attachable))
      p.should_receive(:process_shipment).with([r1])
      p.should_receive(:process_shipment).with([r2])
      p.parse(x)
    end
    it "should ignore lines without a value in row[11] (Container) that starts with 4 letters" do
      p = described_class.new(double(:attachable))
      p.should_not_receive(:process_shipment)
      p.parse(mock_xl_client([default_row({container:'123456788'})]))
    end
    it "should ignore lines with empty container value" do
      p = described_class.new(double(:attachable))
      p.should_not_receive(:process_shipment)
      p.parse(mock_xl_client([default_row({container:nil})]))
    end
  end

  describe :process_shipment do
    before :each do
      @u = Factory(:master_user,shipment_edit:true)
      User.any_instance.stub(:edit_shipments?).and_return true
      Shipment.any_instance.stub(:can_edit?).and_return true
      @p = described_class.new(double(:custom_file))
      @c = Factory(:company,system_code:'LENOX')
      @v = Factory(:company)
      @o = Factory(:order,importer:@c,order_number:'LENOX-ORD123',customer_order_number:'ORD123',vendor:@v)
      @prod = Factory(:product,unique_identifier:'LENOX-PART',importer:@c)
      @ol = @o.order_lines.create!(product_id:@prod.id,quantity:1000)
      @pol = Factory(:port,name:'Yantian, China')
      @pod = Factory(:port,name:'Norfolk, VA')
    end
    it "should create shipment" do
      r = default_row
      expect {@p.process_shipment [r]}.to change(Shipment,:count).from(0).to(1)
      s = Shipment.first
      expect(s.house_bill_of_lading).to eq r[9]
      expect(s.reference).to eq "LENOX-#{r[9]}"
      expect(s.lading_port).to eq @pol
      expect(s.unlading_port).to eq @pod
      expect(s.est_departure_date).to eq Date.new(2014,1,1)
      expect(s.vessel).to eq r[10]
      expect(s.importer).to eq @c
      expect(s.containers.count).to eq 1
      con = s.containers.first
      expect(con.container_number).to eq r[11]
      expect(con.container_size).to eq r[12]
      expect(con.seal_number).to eq r[17]
      expect(s.shipment_lines.count).to eq 1
      sl = s.shipment_lines.first
      expect(sl.line_number).to eq 1
      expect(sl.product).to eq @prod
      expect(sl.order_lines.to_a).to eq [@ol]
      expect(sl.quantity).to eq 100
      expect(sl.container).to eq con
      expect(sl.gross_kgs).to eq BigDecimal(r[14])
      expect(sl.cbms).to eq BigDecimal(r[16])
    end
    it "should clean trailing .0 from product" do
      r = default_row
      r[4] = "#{r[4]}.0"
      @p.process_shipment [r]
      expect(Shipment.first.shipment_lines.first.product).to eq @prod
    end
    it "should skip shipment that already exists" do
      r = default_row
      t = 1.week.ago
      s = Factory(:shipment,reference:"LENOX-#{r[9]}",importer:@c,updated_at:t)
      expect {@p.process_shipment [r]}.to_not change(Shipment.order(:updated_at),:first)
      expect(Shipment.count).to eq 1
    end
    it "should allocate multiple lines to same container" do
      expect {@p.process_shipment [default_row,default_row]}.to change(Container,:count).from(0).to(1)
    end
    it "should allocate to order line with same product and closest unshipped quantity" do
      @ol2 = @o.order_lines.create!(product_id:@prod.id,quantity:101)
      @p.process_shipment [default_row]
      expect(Shipment.first.shipment_lines.first.order_lines.to_a).to eq [@ol2]
    end
    it "should fail if user cannot edit shipments" do
      Shipment.any_instance.stub(:can_edit?).and_return false
      expect {@p.process_shipment [default_row]}.to raise_error
    end
    it "should fail if order doesn't exist" do
      expect {@p.process_shipment [default_row({po:'anotherpo'})]}.to raise_error
    end
    it "should fail if item doesn't exist on order" do
      @ol.update_attributes(product_id:Factory(:product).id)
      expect {@p.process_shipment [default_row({po:'anotherpo'})]}.to raise_error
    end
  end

end