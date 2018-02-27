require 'spec_helper'

describe OpenChain::CustomHandler::JJill::JJill850XmlParser do

  describe "parse" do
    before :each do
      allow_any_instance_of(Order).to receive(:can_edit?).and_return true
      Factory(:master_user,username:'integration')
      @path = 'spec/support/bin/jjill850sample.xml'
      @c = Factory(:company,importer:true,system_code:'JJILL')
      @us = Factory(:country,iso_code:'US')
    end
    def run_file opts = {}
      described_class.parse(IO.read(@path), opts)
    end
    it "should close cancelled order" do
      dom = REXML::Document.new(IO.read(@path))
      REXML::XPath.each(dom.root,'//BEG01') {|el| el.text = '01'}
      expect_any_instance_of(Order).to receive(:close!).with(instance_of(User))
      described_class.parse_dom dom
    end
    it "should reopen order where BEG01 not eq to '03'" do
      o = Factory(:order,importer_id:@c.id,order_number:'JJILL-1001368',closed_by_id:7,closed_at:Time.now)
      DataCrossReference.create_jjill_order_fingerprint!(o,'badfingerprint')
      expect_any_instance_of(Order).to receive(:reopen!).with(instance_of(User))
      expect_any_instance_of(Order).to receive(:post_update_logic!).with(instance_of(User))
      run_file
    end
    it "should save order" do
      cdefs = described_class.prep_custom_definitions [:prod_fish_wildlife, :prod_importer_style, :prod_vendor_style, :prod_part_number, :ord_entry_port_name, :ord_ship_type, :ord_original_gac_date, :ord_line_size, :ord_line_color]
      expect_any_instance_of(Order).to receive(:post_create_logic!).with(instance_of(User))
      expect {run_file}.to change(Order,:count).from(0).to(1)
      o = Order.first

      vend = o.vendor
      expect(vend.system_code).to eq "JJILL-0044198"
      expect(vend.name).to eq "CENTRALAND LMTD"
      expect(vend).to be_vendor

      fact = o.factory
      expect(fact.system_code).to eq 'JJILL-CNCENKNIDON'
      expect(fact.name).to eq "CENTRALAND KNITTING FACTORY"
      expect(fact).to be_factory
      expect(vend.linked_companies).to include(fact)

      expect(o.importer).to eq @c
      expect(@c.linked_companies).to include(vend)

      expect(o.customer_order_number).to eq "1001368"
      expect(o.order_number).to eq "JJILL-1001368"
      expect(o.order_date).to eq Date.new(2014,7,28)
      expect(o.ship_window_start).to eq Date.new(2014,11,4)
      expect(o.ship_window_end).to eq Date.new(2014,11,4)
      expect(o.first_expected_delivery_date).to eq Date.new(2014,12,12)
      expect(o.last_exported_from_source).to eq Time.gm(2014, 7, 29, 23, 6).in_time_zone(Time.zone)
      expect(o.last_revised_date).to eq Date.new(2014,7,29)
      expect(o.mode).to eq 'Ocean'
      expect(o.fob_point).to eq 'CN'
      expect(o.terms_of_sale).to eq 'OA 60 DAYS FROM FCR'
      expect(o.season).to eq '1501'
      expect(o.get_custom_value(cdefs[:ord_entry_port_name]).value).to eq 'Boston'
      expect(o.get_custom_value(cdefs[:ord_ship_type]).value).to eq 'Boat'
      expect(o.get_custom_value(cdefs[:ord_original_gac_date]).date_value).to eq o.ship_window_end
      expect(o.product_category).to eq 'Other'

      st  = o.ship_to
      expect(st.system_code).to eq '0101'
      expect(st.name).to eq 'J JILL'
      expect(st.line_1).to eq 'RECEIVING' #hard coded
      expect(st.line_2).to eq '100 BIRCH POND DRIVE'
      expect(st.city).to eq 'TILTON'
      expect(st.state).to eq 'NH'
      expect(st.postal_code).to eq '03276'
      expect(st.country).to eq @us
      expect(st.company).to eq @c

      expect(o.order_lines.count).to eq 4
      ol1 = o.order_lines.first
      expect(ol1.price_per_unit).to eq 16.4
      expect(ol1.sku).to eq '28332664'
      expect(ol1.hts).to eq '6109100060'
      expect(ol1.custom_value(cdefs[:ord_line_size])).to eq 'XSP'
      expect(ol1.custom_value(cdefs[:ord_line_color])).to eq 'DPBLUEMLT'

      p1 = ol1.product
      expect(p1.unique_identifier).to eq 'JJILL-04-1024'
      expect(p1.name).to eq 'SPACE-DYED COTTON PULLOVER'
      expect(p1.unit_of_measure).to eq 'EA'
      expect(p1.custom_value(cdefs[:prod_vendor_style])).to eq '04-1024'
      expect(p1.custom_value(cdefs[:prod_importer_style])).to eq '014932'
      expect(p1.custom_value(cdefs[:prod_part_number])).to eq '04-1024'

      expected_fingerprint = described_class.new.generate_order_fingerprint o
      expect(DataCrossReference.find_jjill_order_fingerprint(o)).to eq expected_fingerprint

      expect(EntitySnapshot.count).to eq 1
    end
    context "when line numbers are found" do
      it "updates existing order lines when not booked" do
        o = Factory(:order,importer_id:@c.id,order_number:'JJILL-1001368')
        ol = Factory(:order_line, order: o, line_number: 1, quantity: 111 )

        run_file
        ol.reload
        expect(ol.quantity).to eq 299
      end
      it "updates existing order lines when booked" do
        o = Factory(:order,importer_id:@c.id,order_number:'JJILL-1001368')
        ol = Factory(:order_line, order: o, line_number: 1, quantity: 111 )
        s = Factory(:shipment, reference: "REF")
        s.booking_lines.create!(product_id:ol.product_id,quantity:1, order_id: o.id, order_line_id: ol.id)

        run_file
        ol.reload
        expect(ol.quantity).to eq 299
      end
      it "removes order lines not present in the XML" do
        o = Factory(:order,importer_id:@c.id,order_number:'JJILL-1001368')
        Factory(:order_line, order: o, line_number: 5, quantity: 111 )

        run_file
        expect(OrderLine.where(line_number: 5)).to be_empty
      end
    end
    context "when line numbers aren't found" do
      let(:dom) { REXML::Document.new(IO.read(@path)) }
      before { REXML::XPath.each(dom.root,'//PO101') {|el| el.text = ''} }
      
      it "replaces order lines when not booked" do
        o = Factory(:order,importer_id:@c.id,order_number:'JJILL-1001368')
        old_ol = Factory(:order_line, order: o, line_number: 1, quantity: 111 )

        described_class.parse_dom dom
        expect {old_ol.reload}.to raise_error ActiveRecord::RecordNotFound
        new_ol = OrderLine.where(line_number: 1).first
        expect(new_ol.quantity).to eq 299
      end
      it "doesn't change lines when booked" do
        o = Factory(:order,importer_id:@c.id,order_number:'JJILL-1001368')
        ol = Factory(:order_line, order: o, line_number: 1, quantity: 111 )
        s = Factory(:shipment, reference: "REF")
        s.booking_lines.create!(product_id:ol.product_id,quantity:1, order_id: o.id, order_line_id: ol.id)

        described_class.parse_dom dom
        ol.reload
        expect(ol.quantity).to eq 111
      end
    end
    it "should update product name" do
      original_product_name = "SPACE-DYED COTTON PULLOVER"
      new_product_name = "SOMETHING ELSE"
      xml_text = IO.read(@path)

      # first run creates product with original_product_name
      described_class.parse xml_text

      p = Product.first
      expect(p.name).to eq original_product_name

      xml_text.gsub!(original_product_name,new_product_name)

      described_class.parse xml_text

      p.reload
      expect(p.name).to eq new_product_name
    end
    it "should reuse same address based on hash" do
      st  = @c.addresses.create!(system_code:'0101',name:'J JILL',
        line_1:'RECEIVING',line_2:'100 BIRCH POND DRIVE',
        city:'TILTON',state:'NH',postal_code:'03276',country_id:@us.id)
      expect {run_file}.to change(Order,:count).from(0).to(1)
      expect(Order.first.ship_to).to eq st
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
      p = Factory(:product,importer_id:@c.id,unique_identifier:'JJILL-04-1024')
      run_file
      expect(OrderLine.first.product).to eq p
    end
    it "should not use product that isn't for JJILL" do
      p = Factory(:product,importer_id:Factory(:company).id,unique_identifier:'JJILL-04-1024')
      expect {run_file}.to raise_error /Unique identifier/
    end
    it "should update order" do
      o = Factory(:order,importer_id:@c.id,order_number:'JJILL-1001368',approval_status:'Accepted')
      DataCrossReference.create_jjill_order_fingerprint!(o,'badfingerprint')
      run_file
      o.reload
      expect(o.order_lines.count).to eq 4
      expect(o.approval_status).to be_nil
    end
    it "updates booked (but unshipped) order header" do
      o = Factory(:order,importer_id:@c.id,order_number:'JJILL-1001368',fob_point: "PK", approval_status: "Accepted")
      ol = Factory(:order_line,order:o)
      s = Factory(:shipment, reference: "REF")
      s.booking_lines.create!(product_id:ol.product_id,quantity:1, order_id: o.id, order_line_id: ol.id)
      
      run_file
      o.reload
      expect(o.fob_point).to eq "CN"
      expect(o.approval_status).to be_nil
    end
    it "should not update order with newer last_exported_from_source" do
      o = Factory(:order,importer_id:@c.id,order_number:'JJILL-1001368',last_exported_from_source:Date.new(2014,8,1))
      run_file
      o.reload
      expect(o.order_lines).to be_empty
    end
    it "should not change the original GAC custom field if it is already set" do
      o = Factory(:order,importer_id:@c.id,order_number:'JJILL-1001368',ship_window_end:Date.new(2014,12,25))
      cdefs = described_class.prep_custom_definitions [:ord_original_gac_date]
      o.update_custom_value!(cdefs[:ord_original_gac_date], o.ship_window_end)
      run_file
      o.reload
      expect(o.custom_value(cdefs[:ord_original_gac_date])).to eq Date.new(2014,12,25)
    end
    context "notifications" do
      let(:u)   { 3.days.ago }
      let(:o)   { Factory(:order,importer_id:@c.id,order_number:'JJILL-1001368',fob_point: "PK", updated_at:u, approval_status: "Accepted") }
      let(:ol)  { Factory(:order_line,order:o,sku:"SKU") }
      let(:s)   { Factory(:shipment, reference: "REF1", booking_mode: "Air") }
      let(:bl)  { s.booking_lines.create!(product_id:ol.product_id,quantity:1, order_id: o.id, order_line_id: ol.id) }
      let(:s2)  { Factory(:shipment, reference: "REF2") }
      let(:bl2) { s2.booking_lines.create!(product_id:ol.product_id,quantity:1, order_id: o.id, order_line_id: ol.id) }

      it "doesn't update order assigned to multiple bookings" do
        bl; bl2

        run_file
        o.reload
        expect(o.order_lines.to_a).to eq [ol]
        expect(o.fob_point).to eq "PK"
        expect(o.updated_at.to_i).to eq u.to_i

        m = OpenMailer.deliveries.pop
        expect(m).not_to be_nil
        expect(m.to).to eq ["jjill_orders@vandegriftinc.com"]
        expect(m.subject).to eq "[VFI Track] Revisions to JJill Purchase Order 1001368 were Rejected."
        expect(m.body.raw_source).to match(/Revisions for PO 1001368 was rejected because the Purchase Order exists on multiple Shipments: REF1, REF2/)
      end
      it "doesn't update shipped order" do
        bl
        s.shipment_lines.create!(product:ol.product,quantity:1,linked_order_line_id: ol.id)
        
        run_file
        o.reload
        expect(o.order_lines.to_a).to eq [ol]
        expect(o.fob_point).to eq "PK"
        expect(o.updated_at.to_i).to eq u.to_i

        m = OpenMailer.deliveries.pop
        expect(m).not_to be_nil
        expect(m.to).to eq ["jjill_orders@vandegriftinc.com"]
        expect(m.subject).to eq "[VFI Track] Revisions to JJill Purchase Order 1001368 were Rejected."
        expect(m.body.raw_source).to match(/Revisions for PO 1001368 were rejected because the Shipment REF1 was already shipped./)
      end
      it "sends warning if revised order mode and booking mode don't match" do
        bl

        run_file
        o.reload
        expect(o.mode).to eq "Ocean"
        expect(o.approval_status).to be_nil
      
        m = OpenMailer.deliveries.pop
        expect(m).not_to be_nil
        expect(m.to).to eq ["jjill_orders@vandegriftinc.com"]
        expect(m.subject).to eq "[VFI Track] Mode of Transport Discrepancy for PO 1001368 and Shipment REF1"
        expect(m.body.raw_source).to match(/The Mode of Transport for PO 1001368 does not match the Booked Mode of Transport for Shipment REF1/)
      end
      it "matches only first part of the booking mode to the revised order mode" do
        bl
        s.update_attributes! booking_mode: "OCEAN - FCL"

        run_file
        o.reload
        expect(o.mode).to eq "Ocean"
        expect(o.approval_status).to eq "Accepted"
      
        m = OpenMailer.deliveries.pop
        expect(m).to be_nil
      end
      it "should update order header when force_header_updates = true and order on shipment" do
        s.shipment_lines.create!(product:ol.product,quantity:1,linked_order_line_id:ol.id)

        run_file force_header_updates:true

        o.reload
        expect(o.order_lines.to_a).to eq [ol]
        expect(o.fob_point).to eq 'CN'

        m = OpenMailer.deliveries.pop
        expect(m).not_to be_nil
      end
    end
  end
end
