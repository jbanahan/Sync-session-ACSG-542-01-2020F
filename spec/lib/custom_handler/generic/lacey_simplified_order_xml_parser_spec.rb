describe OpenChain::CustomHandler::Generic::LaceySimplifiedOrderXmlParser do
  let(:log) { InboundFile.new }

  describe 'parse_file' do
    it 'should delegate to #parse_dom' do
      data = double('data')
      dom = double('dom')
      expect(REXML::Document).to receive(:new).with(data).and_return(dom)
      opts = double('opts')
      dc = described_class.new(opts)
      expect(described_class).to receive(:new).with(opts).and_return(dc)
      expect(dc).to receive(:parse_dom).with(dom, log)
      described_class.parse_file(data, log, opts)
    end
  end

  describe 'parse_dom' do
    let :base_xml do
      IO.read('spec/fixtures/files/lacey_simplified_order.xml')
    end
    let :base_dom do
      REXML::Document.new(base_xml)
    end
    let :cdefs do
      described_class.prep_custom_definitions [
        :ordln_country_of_harvest,
        :prod_genus,
        :prod_species,
        :prod_cites
      ]
    end
    before :each do
      @importer = create(:company, system_code:'CLIENTCODE', importer:true)
      @china = create(:country, iso_code:'CN')
      @us = create(:country, iso_code:'US')
    end
    it "should map order data" do
      expect {described_class.new.parse_dom(base_dom, log)}.to change(Order, :count).from(0).to(1)
      o = Order.first
      expect(o.importer).to eq @importer
      ven = o.vendor
      expect(ven.system_code).to eq 'ILSI'
      expect(ven.name).to eq 'International Lumber Supplier Inc'
      expect(o.order_number).to eq 'ABC12345'
      expect(o.customer_order_number).to eq 'ABC-12345'
      expect(o.order_date.strftime('%Y-%m-%d')).to eq '2015-07-31'
      expect(o.customer_order_status).to eq 'Open'
      expect(o.last_exported_from_source.iso8601).to eq '2015-08-31T17:26:00Z'
      expect(o.mode).to eq 'Ocean'
      expect(o.ship_window_start).to eq Date.new(2015, 8, 15)
      expect(o.ship_window_end).to eq Date.new(2015, 8, 22)
      expect(o.first_expected_delivery_date).to eq Date.new(2015, 9, 10)
      expect(o.fob_point).to eq 'SHANGHAI'
      expect(o.closed_at.iso8601).to eq '2015-11-16T12:14:00Z'
      expect(o.terms_of_sale).to eq 'FOB'
      expect(o.terms_of_payment).to eq 'NET30'
      expect(o.currency).to eq 'USD'

      sf = o.ship_from
      expect(sf.name).to eq 'ILS create #1'
      expect(sf.line_1).to eq '100 Any Street'
      expect(sf.line_2).to eq 'Shanghai Economic Development Zone'
      expect(sf.line_3).to eq 'Building 301'
      expect(sf.city).to eq 'Shanghai'
      expect(sf.state).to eq 'Shanghai'
      expect(sf.postal_code).to eq 'ABC123'
      expect(sf.country).to eq @china

      expect(o.order_lines.count).to eq 2

      ol = o.order_lines.find {|ln| ln.line_number==1}
      expect(ol.quantity).to eq 307.4
      expect(ol.price_per_unit).to eq 1.21
      expect(ol.unit_of_measure).to eq 'FT2'
      expect(ol.country_of_origin).to eq 'CN'
      expect(ol.custom_value(cdefs[:ordln_country_of_harvest])).to eq 'BR'
      expect(ol.hts).to eq '4418904685'
      expect(ol.sku).to eq 'BRCHERFL0318'

      st = ol.ship_to
      expect(st.name).to eq 'Yard 1'
      expect(st.line_1).to eq '4 Pennsylvania Plaza'
      expect(st.city).to eq 'New York'
      expect(st.state).to eq 'NY'
      expect(st.postal_code).to eq '10001'
      expect(st.country).to eq @us

      prod = ol.product
      expect(prod.unique_identifier).to eq 'BRCHERFL'
      expect(prod.name).to eq 'Brazilian Cherry Flooring'
      expect(prod.custom_value(cdefs[:prod_genus])).to eq 'Hymenaea'
      expect(prod.custom_value(cdefs[:prod_species])).to eq 'courbaril'
      expect(prod.custom_value(cdefs[:prod_cites])).to be_truthy

      expect(o.order_lines.last.product.custom_value(cdefs[:prod_cites])).to be_falsey

      expect(o.entity_snapshots.count).to eq 1

      expect(log.company).to eq @importer
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[0].value).to eq "ABC12345"
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[0].module_type).to eq "Order"
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[0].module_id).to eq o.id
    end
    it "should update existing order" do
      ord = create(:order, order_number:'ABC12345', importer:@importer)
      expect {described_class.new.parse_dom(base_dom, log)}.to_not change(Order, :count)
      ord.reload
      expect(ord.customer_order_number).to eq 'ABC-12345'

      expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[0].module_id).to eq ord.id
    end
    it "should find existing vendor by system code (even if name is different) and update name on Company record" do
      ven = create(:company, vendor:true, system_code:'ILSI', name:'x')
      expect {described_class.new.parse_dom(base_dom, log)}.to_not change(Company.where(vendor:true), :count)
      ven.reload
      ord = Order.first
      expect(ord.vendor).to eq ven
      expect(ven.name).to eq 'International Lumber Supplier Inc'
    end
    it "should use existing ship from based on hash" do
      ven = create(:company, vendor:true, system_code:'ILSI')
      sf = ven.addresses.create!(
        name: 'ILS create #1',
        line_1: '100 Any Street',
        line_2: 'Shanghai Economic Development Zone',
        line_3: 'Building 301',
        city: 'Shanghai',
        state: 'Shanghai',
        postal_code: 'ABC123',
        shipping: true,
        country: @china
      )
      expect {described_class.new.parse_dom(base_dom, log)}.to_not change(ven.addresses, :count)
      expect(Order.first.ship_from).to eq sf
    end
    it "should use existing product" do
      p = create(:product, unique_identifier:'BRCHERFL')
      described_class.new.parse_dom(base_dom, log)
      ord = Order.first
      expect(ord.order_lines.first.product).to eq p
      expect(ProductVendorAssignment.where(vendor_id:ord.vendor_id, product_id:p.id).first).to_not be_nil
    end
    it "should use existing ship to based on hash" do
      st = @importer.addresses.create!(
        name: 'Yard 1',
        line_1: '4 Pennsylvania Plaza',
        city: 'New York',
        state: 'NY',
        postal_code: '10001',
        country: @us,
        shipping:true
      )
      expect {described_class.new.parse_dom(base_dom, log)}.to_not change(@importer.addresses, :count)
      expect(Order.first.order_lines.first.ship_to).to eq st
    end
    it "should fail if root element is wrong" do
      base_xml.gsub!('Order>', 'Other>')
      expect {described_class.new.parse_dom(base_dom, log)}.to raise_error(/invalid root element/)
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_ERROR)[0].message).to eq "XML has invalid root element \"Other\", expecting \"Order\""
      expect(Order.count).to eq 0
    end
    it "should fail if Importer isn't found" do
      base_xml.gsub!('CLIENTCODE', 'OTHERCODE')
      expect {described_class.new.parse_dom(base_dom, log)}.to raise_error(/Importer was not found/)
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "Importer was not found for ImporterId \"OTHERCODE\""
      expect(Order.count).to eq 0
    end
    it "should fail if Importer isn't an importer company" do
      @importer.update_attributes(importer:false)
      expect {described_class.new.parse_dom(base_dom, log)}.to raise_error(/Importer was not found/)
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "Importer was not found for ImporterId \"CLIENTCODE\""
      expect(Order.count).to eq 0
    end
    it "should delete other lines" do
      ord = create(:order, order_number:'ABC12345', importer:@importer)
      ol = create(:order_line, order:ord, line_number:999)
      expect {described_class.new.parse_dom(base_dom, log)}.to change(OrderLine, :count).from(1).to(2)
      expect(OrderLine.find_by_id(ol.id)).to be_nil
    end
    it "should fail if summary total lines doesn't match" do
      base_xml.gsub!('TotalLines>2', 'TotalLines>3')
      expect {described_class.new.parse_dom(base_dom, log)}.to raise_error(/TotalLines/)
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "TotalLines was 3 but order had 2 lines."
    end
    it "should fail if summary total quantity doesn't match" do
      base_xml.gsub!('Quantity>708.9', 'Quantity>709.9')
      expect {described_class.new.parse_dom(base_dom, log)}.to raise_error(/Quantity/)
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "Summary Quantity was 709.9 but actual total was 708.9"
    end
    it "should not reprocess old files" do
      ord = create(:order, order_number:'ABC12345', importer:@importer, customer_order_number:'OTHER', last_exported_from_source:100.years.from_now)
      expect {described_class.new.parse_dom(base_dom, log)}.to_not change(OrderLine, :count)
      ord.reload
      expect(ord.customer_order_number).to eq 'OTHER'
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_INFO)[0].message).to eq "Order not updated: file contained outdated info."
    end
    context 'required fields' do
      it "should require ImporterId" do
        base_xml.gsub!('ImporterId>CLIENTCODE', 'ImporterId>')
        expect {described_class.new.parse_dom(base_dom, log)}.to raise_error(/ImporterId is required/)
        expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "ImporterId is required"
        expect(Order.count).to eq 0
      end
      it "should require VendorNumber" do
        base_xml.gsub!('VendorNumber>ILSI', 'VendorNumber>')
        expect {described_class.new.parse_dom(base_dom, log)}.to raise_error(/VendorNumber is required/)
        expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "VendorNumber is required"
        expect(Order.count).to eq 0
      end
      it "should require OrderNumber" do
        base_xml.gsub!('OrderNumber>ABC12345', 'OrderNumber>')
        expect {described_class.new.parse_dom(base_dom, log)}.to raise_error(/OrderNumber is required/)
        expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "OrderNumber is required"
        expect(Order.count).to eq 0
      end
      it "should require CustomerOrderNumber" do
        base_xml.gsub!('CustomerOrderNumber>ABC-12345', 'CustomerOrderNumber>')
        expect {described_class.new.parse_dom(base_dom, log)}.to raise_error(/CustomerOrderNumber is required/)
        expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "CustomerOrderNumber is required"
        expect(Order.count).to eq 0
      end
      it "should require OrderDate" do
        base_xml.gsub!('OrderDate>2015-07-31', 'OrderDate>')
        expect {described_class.new.parse_dom(base_dom, log)}.to raise_error(/OrderDate is required/)
        expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "OrderDate is required"
        expect(Order.count).to eq 0
      end
      it "should require SystemExtractDate" do
        base_xml.gsub!('SystemExtractDate>2015-08-31T13:26:00-04:00', 'SystemExtractDate>')
        expect {described_class.new.parse_dom(base_dom, log)}.to raise_error(/SystemExtractDate is required/)
        expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "SystemExtractDate is required"
        expect(Order.count).to eq 0
      end
      context 'line' do
        it "should require LineNumber" do
          base_xml.gsub!('LineNumber>1', 'LineNumber>')
          expect {described_class.new.parse_dom(base_dom, log)}.to raise_error(/LineNumber is required/)
          expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "LineNumber is required"
          expect(Order.count).to eq 0
        end
        it "should require OrderedQuantity" do
          base_xml.gsub!('OrderedQuantity>307.4', 'OrderedQuantity>')
          expect {described_class.new.parse_dom(base_dom, log)}.to raise_error(/OrderedQuantity is required/)
          expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "OrderedQuantity is required"
          expect(Order.count).to eq 0
        end
        it "should require PricePerUnit" do
          base_xml.gsub!('PricePerUnit>1.21', 'PricePerUnit>')
          expect {described_class.new.parse_dom(base_dom, log)}.to raise_error(/PricePerUnit is required/)
          expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "PricePerUnit is required"
          expect(Order.count).to eq 0
        end
        it "should require UnitOfMeasure" do
          base_xml.gsub!('UnitOfMeasure>FT2', 'UnitOfMeasure>')
          expect {described_class.new.parse_dom(base_dom, log)}.to raise_error(/UnitOfMeasure is required/)
          expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "UnitOfMeasure is required"
          expect(Order.count).to eq 0
        end
        it "should require UniqueIdentifier" do
          base_xml.gsub!('UniqueIdentifier>BRCHERFL', 'UniqueIdentifier>')
          expect {described_class.new.parse_dom(base_dom, log)}.to raise_error(/UniqueIdentifier is required/)
          expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "OrderLine/Product/UniqueIdentifier is required"
          expect(Order.count).to eq 0
        end
      end
    end
  end
end
