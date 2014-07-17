require 'spec_helper'

describe OpenChain::CustomHandler::JJill::JJill850XmlParser do
  describe :parse do
    before :each do
      Order.any_instance.stub(:can_edit?).and_return true
      @u = Factory(:master_user)
      @path = 'spec/support/bin/jjill850sample.xml'
      @c = Factory(:company,importer:true,system_code:'JJILL')
    end
    def run_file
      described_class.parse(IO.read(@path),@u)
    end
    it "should save order" do
      expect {run_file}.to change(Order,:count).from(0).to(2)
      o = Order.first
      vend = o.vendor
      expect(vend.system_code).to eq "JJILL-0201223"
      expect(vend.name).to eq "KYUNG SEUNG CO LTD"
      expect(o.customer_order_number).to eq "7800374"
      expect(o.order_number).to eq "JJILL-7800374"
      expect(o.order_date).to eq Date.new(2014,3,31)
      expect(o.last_exported_from_source.strftime("%Y%m%d%H%M")).to eq '201404142308'

      expect(o.order_lines.count).to eq 3
      ol1 = o.order_lines.first
      expect(ol1.price_per_unit).to eq 6.39
      expect(ol1.sku).to eq '21378072'
      expect(ol1.hts).to eq '6109100060'

      p1 = ol1.product
      expect(p1.unique_identifier).to eq 'JJILL-704394'
      expect(p1.name).to eq 'PERFECT TANK'

      expect(o.entity_snapshots.count).to eq 1
    end

    it "should use existing vendor" do
      vn = Factory(:company,name:'KYUNG SEUNG CO LNTD',system_code:'JJILL-0201223',vendor:true)
      run_file
      expect(Order.first.vendor).to eq vn
    end
    it "should use existing product" do
      p = Factory(:product,importer_id:@c.id,unique_identifier:'JJILL-704394')
      run_file
      expect(OrderLine.first.product).to eq p
    end
    it "should not use product that isn't for JJILL" do
      p = Factory(:product,importer_id:Factory(:company).id,unique_identifier:'JJILL-704394')
      expect {run_file}.to raise_error /Unique identifier/
    end
    it "should update order" do
      o = Factory(:order,importer_id:@c.id,order_number:'JJILL-7800374')
      run_file
      o.reload
      expect(o.order_lines.count).to eq 3
    end
    it "should not update order with newer last_exported_from_source" do
      o = Factory(:order,importer_id:@c.id,order_number:'JJILL-7800374',last_exported_from_source:Date.new(2014,5,1))
      run_file
      o.reload
      expect(o.order_lines).to be_empty
    end
    it "should not update order already on a shipment" do
      u = 3.days.ago
      o = Factory(:order,importer_id:@c.id,order_number:'JJILL-7800374',updated_at:u)
      ol = Factory(:order_line,order:o)
      s = Factory(:shipment)
      sl = s.shipment_lines.build(product_id:ol.product_id,quantity:1)
      sl.linked_order_line_id = ol.id
      sl.save!

      run_file
      o.reload
      expect(o.order_lines.to_a).to eq [ol]
      expect(o.updated_at.to_i).to eq u.to_i
    end
  end
end