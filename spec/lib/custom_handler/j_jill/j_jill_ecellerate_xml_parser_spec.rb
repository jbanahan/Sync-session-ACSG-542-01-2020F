require 'spec_helper'

describe OpenChain::CustomHandler::JJill::JJillEcellerateXmlParser do
  describe "parse_dom" do
    before :all do
      @dom = REXML::Document.new(IO.read('spec/support/bin/jjill_ecellerate_sample.xml'))
    end
    before :each do
      Factory(:master_user,username:'integration')
      @jill = Factory(:company,ecellerate_customer_number:'JILSO',importer:true)
      @ord = Factory(:order,importer:@jill,order_number:'JJILL-7800374',customer_order_number:'7800374')
      @prod = Factory(:product,importer:@jill,unique_identifier:'JIll-704394')
      @ol1 = @ord.order_lines.create!(product_id:@prod.id,quantity:100,sku:'21378072')
      @ord.order_lines.create!(product_id:@prod.id,quantity:100,sku:'21378058')
    end
    let (:log) { InboundFile.new }

    it "should create shipment" do
      expect {described_class.parse_dom @dom, log}.to change(Shipment,:count).from(0).to(1)
      s = Shipment.first
      expect(s.importer).to eq @jill
      expect(s.reference).to eq "JJILL-20140618039566"
      expect(s.master_bill_of_lading).to eq "695-35416636"
      expect(s.house_bill_of_lading).to eq 'SGN140008'
      expect(s.mode).to eq 'Air'

      lines = s.shipment_lines
      expect(lines.count).to eq 4
      l1 = s.shipment_lines.first
      expect(l1.product).to eq @prod
      expect(l1.order_lines.to_a).to eq [@ol1]
      expect(l1.quantity).to eq 4
      expect(l1.container).to be_nil
      expect(l1.line_number).to eq 1

      expect(s.containers.count).to eq 1
      cont = s.containers.first
      expect(cont.container_number).to eq 'CSLU1586141'
      expect(cont.seal_number).to eq 'T445187'
      expect(cont.weight).to eq 1542
      expect(cont.container_size).to eq "2000"

      l4 = s.shipment_lines.last
      expect(l4.product).to eq @prod
      expect(l4.container).to eq cont
      expect(l4.quantity).to eq 750
      expect(l4.line_number).to eq 4

      expect(s.entity_snapshots.count).to eq 1

      expect(log.company).to eq @jill
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_SHIPMENT_NUMBER)[0].value).to eq "20140618039566"
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_SHIPMENT_NUMBER)[0].module_type).to eq "Shipment"
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_SHIPMENT_NUMBER)[0].module_id).to eq s.id
    end
    it "should update existing lines" do
      described_class.parse_dom @dom, InboundFile.new
      s = Shipment.first
      expect(s.shipment_lines.inject(0) {|x,ln| x+ln.quantity }).to_not eq 4
      REXML::XPath.each(@dom.root,'//QuantityShipped') {|el| 
        el.text = 1
      }
      described_class.parse_dom @dom, log
      s.reload
      expect(s.shipment_lines.count).to eq 4
      expect(s.shipment_lines.inject(0) {|x,ln| x+ln.quantity }).to eq 4
    end

    it "should fail on shipment line mismatch" do
      described_class.parse_dom @dom, InboundFile.new

      sl = ShipmentLine.first
      sl.update_attribute(:line_number, 666)

      expect {described_class.parse_dom @dom, log}.to raise_error "Shipment Line with ID #{sl.id} had line number 666 instead of expected line number 1"
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "Shipment Line with ID #{sl.id} had line number 666 instead of expected line number 1"
    end

    it "should fail on missing order line" do
      @ol1.destroy
      expect {described_class.parse_dom @dom, log}.to raise_error "Order 7800374 does not have SKU 21378072"
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "Order 7800374 does not have SKU 21378072"
    end

    it "should fail on missing order" do
      @ord.destroy
      expect {described_class.parse_dom @dom, log}.to raise_error "Order 7800374 not found"
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "Order 7800374 not found"
    end

    it "should skip file that has been more recently exported" do
      #destroying the order line would cause the file to raise an exception if it wasn't skipped,
      #so completing this without an error means we're getting the expected behavior
      @ol1.destroy
      Factory(:shipment,reference:'JJILL-20140618039566',last_exported_from_source:1.minute.ago,importer_id:@jill.id)
      REXML::XPath.first(@dom.root,'//TransactionDateTime').text= '2014-07-10T12:22:01.00-05:00'
      expect {described_class.parse_dom @dom, log}.to_not raise_error

      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_INFO)[0].message).to eq "Shipment not updated: file contained outdated info."
    end
  end
end