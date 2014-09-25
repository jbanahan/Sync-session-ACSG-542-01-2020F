require 'spec_helper'

describe OpenChain::CustomHandler::Hm::HmShipmentParser do
  before(:each) do
    @air_path = 'spec/support/bin/hm_air.txt'
    @ocean_path = 'spec/support/bin/hm_ocean.txt'
    @u = Factory(:user)
    @hm = Factory(:company,importer:true,system_code:'HENNE')
    @cdefs = described_class.prep_custom_definitions described_class::CUSTOM_DEFINITION_INSTRUCTIONS.keys
    described_class.stub(:attach_file).and_return nil
  end
  describe :parse do
    before :each do
      [Order,Shipment,CommercialInvoice,Product].each {|k| k.any_instance.stub(:can_edit?).and_return true}
      [:edit_orders?,:edit_commercial_invoices?,:edit_shipments?,:edit_products?].each {|p| @u.stub(p).and_return true}
    end
    it "should skip non US files" do
      described_class.stub(:process_second_line).and_return ['ABC.MX','12345']
      expect{described_class.parse(IO.read(@air_path),@u)}.to_not change(Shipment,:count)
    end
    context :permission_issues do
      after :each do
        expect(Shipment.count).to eq 0
      end
      it "should fail if user cannot edit shipment" do
        Shipment.any_instance.should_receive(:can_edit?).with(@u).and_return false
        expect{described_class.parse(IO.read(@air_path),@u)}.to raise_error /permission to edit this shipment/
      end
      it "should fail if user cannot edit product" do
        Product.any_instance.should_receive(:can_edit?).with(@u).and_return false
        expect{described_class.parse(IO.read(@air_path),@u)}.to raise_error /permission to edit this product/
      end
      it "should fail if user cannot edit order" do
        Order.any_instance.should_receive(:can_edit?).with(@u).and_return false
        expect{described_class.parse(IO.read(@air_path),@u)}.to raise_error /permission to edit this order/
      end
      it "should fail if user cannot edit commercial invoice" do
        CommercialInvoice.any_instance.should_receive(:can_edit?).with(@u).and_return false
        expect{described_class.parse(IO.read(@air_path),@u)}.to raise_error /permission to edit this commercial invoice/
      end
    end
    context :ocean do
      it "should error if first line doesn't have TRANSPORT INFORMATION" do
        d = "XYZ"
        expect{described_class.parse(d,@u)}.to raise_error /First line must start with TRANSPORT INFORMATION/
      end
      it "should create ocean shipment from multi-page document" do
        Shipment.any_instance.should_receive(:create_snapshot).with(@u) #much faster to not run this
        expect{described_class.parse(IO.read(@ocean_path),@u)}.to change(Shipment,:count).from(0).to(1)
        s = Shipment.first
        expect(s.importer).to eq @hm
        expect(s.reference).to eq "HENNE-38317-23-SEP-2014"
        expect(s.importer_reference).to eq '38317'
        expect(s.vessel).to eq 'HANOVER EXPRESS'
        expect(s.voyage).to eq '051E'
        expect(s.est_arrival_port_date).to eq Date.new(2014,10,5)
        expect(s.est_departure_date).to eq Date.new(2014,9,21)
        expect(s.containers.size).to eq 1
        expect(s.mode).to eq 'Ocean'
        expect(s.receipt_location).to eq 'Shanghai'
        con = s.containers.first
        expect(con.container_number).to eq 'MOFU0736537'
        expect(con.container_size).to eq '40STD'
        expect(con.seal_number).to eq 'BA40376'
        expect(con.shipment_lines.count).to eq 2

        #shipment lines
        expect(s.shipment_lines.count).to eq 2
        sl = s.shipment_lines.first
        expect(sl.quantity).to eq 234
        expect(sl.carton_qty).to eq 10
        expect(sl.cbms).to eq BigDecimal('0.64')
        expect(sl.gross_kgs).to eq 42
        expect(sl.fcr_number).to eq '190741600'

        #product setup
        p = sl.product
        expect(p.importer).to eq @hm
        expect(p.unique_identifier).to eq 'HENNE-100309'
        expect(p.get_custom_value(@cdefs[:prod_part_number]).value).to eq '100309'

        #order setup
        expect(sl.order_lines.count).to eq 1
        ol = sl.order_lines.first
        expect(ol.product).to eq p
        expect(ol.quantity).to eq 234
        expect(ol.get_custom_value(@cdefs[:ol_dest_code]).value).to eq 'US0004'
        expect(ol.get_custom_value(@cdefs[:ol_dept_code]).value).to eq 'OU'
        o = ol.order
        expect(o.importer).to eq @hm
        expect(o.order_number).to eq 'HENNE-100309'
        expect(o.customer_order_number).to eq '100309'

        #commercial invoice setup
        expect(sl.commercial_invoice_lines.count).to eq 1
        cil = sl.commercial_invoice_lines.first
        ci = cil.commercial_invoice
        expect(ci.invoice_number).to eq '100309'
        expect(ci.importer).to eq @hm
      end
      it "should add container to existing shipment by importer_reference and voyage" do
        s = Factory(:shipment,importer:@hm,reference:'HENNE-38317-23-SEP-2014',voyage:'051E',importer_reference:'38317')
        expect{described_class.parse(IO.read(@ocean_path),@u)}.to_not change(Shipment,:count)
        s.reload
        expect(s.shipment_lines.size).to eq 2
      end
      it "should link to existing commercial invoice lines by PO importer and quantity" do
        cil = Factory(:commercial_invoice_line,
          commercial_invoice:Factory(:commercial_invoice,importer:@hm,invoice_number:'100309'),
          quantity:234
        )
        described_class.parse(IO.read(@ocean_path),@u)
        cil.reload
        expect(cil.shipment_lines.count).to eq 1
      end
      it "should not duplicate lines when loading a sea shipment twice" do
        expect{described_class.parse(IO.read(@ocean_path),@u)}.to change(ShipmentLine,:count).from(0).to(2)
        expect{described_class.parse(IO.read(@ocean_path),@u)}.to_not change(ShipmentLine,:count)
      end
    end
    context :air do
      it "should load air shipment without container" do
        expect{described_class.parse(IO.read(@air_path),@u)}.to change(Shipment,:count).from(0).to(1)
        s = Shipment.first
        expect(s.mode).to eq 'Air'
        expect(s.containers.count).to eq 0
        expect(s.shipment_lines.count).to eq 3
      end
      it "should use ActRcv if FinRcv is blank" do
        described_class.parse(IO.read(@air_path),@u)
        sl = ShipmentLine.first
        expect(sl.order_lines.first.get_custom_value(@cdefs[:ol_dest_code]).value).to eq 'US0004'
      end
      it "should not duplicate lines on an air shipment" do
        expect{described_class.parse(IO.read(@air_path),@u)}.to change(ShipmentLine,:count).from(0).to(3)
        expect{described_class.parse(IO.read(@air_path),@u)}.to_not change(ShipmentLine,:count)
      end
      it "should create multiple order lines linked to the same commercial invoice line for the same order" do
        expect{described_class.parse(IO.read(@air_path),@u)}.to change(Order,:count).from(0).to(2)
        expect(Order.last.order_lines.count).to eq 2
        expect(CommercialInvoiceLine.count).to eq 2
      end
    end
    it "should attach file to shipment" do
      described_class.rspec_reset #we're stubbing this for speed in the other methods
      expect{described_class.parse(IO.read(@air_path),@u)}.to change(Attachment,:count).from(0).to(1)
      expect(Shipment.first.attachments.first.attached_file_name).to eq 'DAPAAL20140923010828556U2577613690.US.txt'
    end
  end
end