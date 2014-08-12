require 'spec_helper'

describe OpenChain::CustomHandler::JJill::JJill850XmlParser do
  describe :parse do
    before :each do
      Order.any_instance.stub(:can_edit?).and_return true
      Factory(:master_user,username:'integration')
      @path = 'spec/support/bin/jjill850sample.xml'
      @c = Factory(:company,importer:true,system_code:'JJILL')
    end
    def run_file opts = {}
      described_class.parse(IO.read(@path), opts)
    end
    it "should save order" do
      expect {run_file}.to change(Order,:count).from(0).to(1)
      o = Order.first
      vend = o.vendor
      expect(vend.system_code).to eq "JJILL-0044198"
      expect(vend.name).to eq "CENTRALAND LMTD"
      expect(vend).to be_vendor
      expect(o.importer).to eq @c
      expect(@c.linked_companies).to include(vend)
      expect(o.customer_order_number).to eq "1001368"
      expect(o.order_number).to eq "JJILL-1001368"
      expect(o.order_date).to eq Date.new(2014,7,28)
      expect(o.ship_window_start).to eq Date.new(2014,11,4)
      expect(o.ship_window_end).to eq Date.new(2014,11,4)
      expect(o.first_expected_delivery_date).to eq Date.new(2014,12,12)
      expect(o.last_exported_from_source.strftime("%Y%m%d%H%M")).to eq '201407292306'
      expect(o.last_revised_date).to eq Date.new(2014,7,29)
      expect(o.mode).to eq 'Ocean'
      expect(o.fob_point).to eq 'CN'

      expect(o.order_lines.count).to eq 4
      ol1 = o.order_lines.first
      expect(ol1.price_per_unit).to eq 16.4
      expect(ol1.sku).to eq '28332664'
      expect(ol1.hts).to eq '6109100060'

      p1 = ol1.product
      expect(p1.unique_identifier).to eq 'JJILL-014932'
      expect(p1.name).to eq 'SPACE-DYED COTTON PULLOVER'
      cdefs = described_class.prep_custom_definitions [:vendor_style]
      expect(p1.get_custom_value(cdefs[:vendor_style]).value).to eq '04-1024'

      expect(o.entity_snapshots.count).to eq 1
    end
    it "should set mode to Air for 'A'" do
      dom = REXML::Document.new(IO.read(@path))
      REXML::XPath.each(dom.root,'//TD504') {|el| el.text = 'A'}
      described_class.parse_dom dom
      expect(Order.first.mode).to eq 'Air'
    end

    it "should auto assign agent if only one exists" do
      agent = Factory(:company,agent:true)
      @c.linked_companies << agent
      vn = Factory(:company,name:'CENTRALAND LMTD',system_code:'JJILL-0044198',vendor:true)
      vn.linked_companies << agent
      run_file
      expect(Order.first.agent).to eq agent

    end

    it "should use existing vendor" do
      vn = Factory(:company,name:'CENTRALAND LMTD',system_code:'JJILL-0044198',vendor:true)
      run_file
      expect(Order.first.vendor).to eq vn
    end
    it "should use existing product" do
      p = Factory(:product,importer_id:@c.id,unique_identifier:'JJILL-014932')
      run_file
      expect(OrderLine.first.product).to eq p
    end
    it "should not use product that isn't for JJILL" do
      p = Factory(:product,importer_id:Factory(:company).id,unique_identifier:'JJILL-014932')
      expect {run_file}.to raise_error /Unique identifier/
    end
    it "should update order" do
      o = Factory(:order,importer_id:@c.id,order_number:'JJILL-1001368')
      run_file
      o.reload
      expect(o.order_lines.count).to eq 4
    end
    it "should not update order with newer last_exported_from_source" do
      o = Factory(:order,importer_id:@c.id,order_number:'JJILL-1001368',last_exported_from_source:Date.new(2014,8,1))
      run_file
      o.reload
      expect(o.order_lines).to be_empty
    end
    it "should not update order already on a shipment" do
      u = 3.days.ago
      o = Factory(:order,importer_id:@c.id,order_number:'JJILL-1001368',updated_at:u)
      ol = Factory(:order_line,order:o)
      s = Factory(:shipment)
      sl = s.shipment_lines.build(product_id:ol.product_id,quantity:1)
      sl.linked_order_line_id = ol.id
      sl.save!

      run_file
      o.reload
      expect(o.order_lines.to_a).to eq [ol]
      expect(o.updated_at.to_i).to eq u.to_i

      m = OpenMailer.deliveries.pop
      expect(m).not_to be_nil
      expect(m.to).to eq ["jjill_orders@vandegriftinc.com"]
      expect(m.subject).to eq "[VFI Track] Order #1001368 already assigned to a Shipment"

    end
    it "should update order header when force_header_updates = true and order on shipment" do
      o = Factory(:order,importer_id:@c.id,order_number:'JJILL-1001368')
      ol = Factory(:order_line,order:o)
      s = Factory(:shipment)
      sl = s.shipment_lines.build(product_id:ol.product_id,quantity:1)
      sl.linked_order_line_id = ol.id
      sl.save!

      run_file force_header_updates:true

      o.reload
      expect(o.order_lines.to_a).to eq [ol]
      expect(o.fob_point).to eq 'CN'

      m = OpenMailer.deliveries.pop
      expect(m).not_to be_nil
    end
  end
end