require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberExpeditorsBookingXmlGenerator do
  describe '#generate_xml' do
    def match_address xml, address
      expect(address.name).to eq xml.text('name')
      expect(address.line_1).to eq xml.text('line-1') unless address.line_1.blank?
      expect(address.line_2).to eq xml.text('line-2') unless address.line_2.blank?
      expect(address.line_3).to eq xml.text('line-3') unless address.line_3.blank?
      expect(address.city).to eq xml.text('city')
      expect(address.state).to eq xml.text('state')
      expect(address.postal_code).to eq xml.text('postal-code')
      expect(address.country.iso_code).to eq xml.text('country')
    end
    let :coo_cdef do
      double('country_of_origin definition')
    end
    let :prod_merch_cat_def do
      double('prod_merch_cat definition')
    end
    let :cdefs do
      {
        ord_country_of_origin:coo_cdef,
        prod_merch_cat:prod_merch_cat_def
      }
    end
    let :usa do
      c = Country.new
      c.iso_code = 'US'
      c
    end
    let :first_port_receipt do
      Port.new(unlocode:'CNSHA')
    end
    let :vendor do
      Company.new(system_code:'VENSYS')
    end
    let :product1 do
      p = Product.new(unique_identifier:'PROD1',name:'PNAME1')
      p.classifications.build(country:usa).tariff_records.build(hts_1:'1234567890')
      allow(p).to receive(:custom_value).with(prod_merch_cat_def).and_return "MERCHCAT"
      p
    end
    let :ship_to do
      Address.new(system_code:'SHPTOSYS')
    end
    let :ship_from do
      Address.new(name:'A1Name',line_1:'A1A',city:'A1C',state:'A1S',postal_code:'A1P',country:usa)
    end
    let :order1 do
      o = Order.new(
        order_number:'ORDNUM1',
        currency:'USD',
        ship_window_start:Date.new(2016,9,10),
        ship_window_end:Date.new(2016,9,15),
        terms_of_sale:'FOB'
      )
      o.order_lines.build(
        line_number:1,
        product:product1,
        quantity:50.25,
        unit_of_measure:'EA',
        price_per_unit:22.14,
        ship_to:ship_to
      )
      allow(o).to receive(:custom_value).with(coo_cdef).and_return 'CN'
      o
    end
    let :product2 do
      p = Product.new(unique_identifier:'PROD2',name:'PNAME2')
      allow(p).to receive(:custom_value).with(prod_merch_cat_def).and_return "MERCHCAT"
      p
    end
    let :order2 do
      o = Order.new(order_number:'ORDNUM2',currency:'USD')
      o.order_lines.build(
        line_number:1,
        product:product2,
        quantity:75.55,
        unit_of_measure:'EA',
        price_per_unit:14.21
      )
      allow(o).to receive(:custom_value).with(coo_cdef).and_return 'CN'
      o
    end

    let :shipment do
      s = Shipment.new(
        reference:'SHPREF',
        requested_equipment:"2 40\n3 40HC",
        cargo_ready_date:Date.new(2016,8,31),
        booking_mode:'Air',
        booking_shipment_type:'CY',
        vendor:vendor,
        ship_from:ship_from,
        first_port_receipt:first_port_receipt
      )
      b1 = s.booking_lines.build
      b1.product = product1
      b1.order_line = order1.order_lines.first
      b1.quantity = b1.order_line.quantity
      b2 = s.booking_lines.build
      b2.product = product2
      b2.order_line = order2.order_lines.first
      b2.quantity = b2.order_line.quantity
      s
    end
    it "should generate base xml" do
      xml = described_class.generate_xml(shipment,cdefs)
      root = xml.root
      expect(root.name).to eq 'booking'
      expect(root.text('reference')).to eq shipment.reference
      expect(root.text('canceled-date')).to be_blank

      requested_equipment = root.elements['requested-equipment']
      expect(requested_equipment.elements.size).to eq 2
      equip1 = requested_equipment.elements['equipment[1]']
      expect(equip1.attributes['type']).to eq '40'
      expect(equip1.text).to eq '2'
      equip2 = requested_equipment.elements['equipment[2]']
      expect(equip2.attributes['type']).to eq '40HC'
      expect(equip2.text).to eq '3'

      expect(root.text('cargo-ready-date')).to eq '20160831'
      expect(root.text('mode')).to eq 'AIR'
      expect(root.text('service-type')).to eq shipment.booking_shipment_type
      expect(root.text('vendor-system-code')).to eq 'VENSYS'
      expect(root.text('origin-port')).to eq 'CNSHA'
      expect(root.text('consignee-name')).to eq 'Lumber Liquidators'

      booking_lines = root.elements['booking-lines']
      expect(booking_lines.elements.size).to eq 2
      bl1 = booking_lines.elements['booking-line[1]']
      expect(bl1.text('order-line-number')).to eq '1'
      expect(bl1.text('order-number')).to eq 'ORDNUM1'
      expect(bl1.text('part-number')).to eq 'PROD1'
      expect(bl1.text('part-name')).to eq 'PNAME1'
      expect(bl1.text('quantity')).to eq '50.25'
      expect(bl1.text('unit-of-measure')).to eq 'EA'
      expect(bl1.text('unit-price')).to eq '22.14'
      expect(bl1.text('currency')).to eq 'USD'
      expect(bl1.text('country-of-origin')).to eq 'CN'
      expect(bl1.text('hts-code')).to eq '1234567890'
      expect(bl1.text('department')).to eq 'MERCHCAT'
      expect(bl1.text('warehouse')).to eq 'SHPTOSYS'
      expect(bl1.text('item-early-ship-date')).to eq '20160910'
      expect(bl1.text('item-late-ship-date')).to eq '20160915'
      expect(bl1.text('inco-terms')).to eq 'FOB'

      match_address(root.elements['address[@type="stuffing"][1]'],ship_from)
      match_address(root.elements['address[@type="seller"][1]'],ship_from)
      match_address(root.elements['address[@type="manufacturer"][1]'],ship_from)
      ll_corp = Address.new(
        name:'Lumber Liquidators',
        line_1:'3000 John Deere Rd',
        city: 'Toano',
        state: 'VA',
        postal_code:'23168',
        country:usa
      )
      match_address(root.elements['address[@type="buyer"][1]'],ll_corp)
    end

    it "should generate canceled_date" do
      s = shipment
      s.canceled_date = Time.now
      xml = described_class.generate_xml(s,cdefs)
      expect(xml.root.text('canceled-date')).to match(/^[0-9]{4}/)
    end
    it "should fail on mode other than AIR or OCEAN" do
      s = shipment
      s.booking_mode = 'Truck'
      expect{described_class.generate_xml(s,cdefs)}.to raise_error(/Invalid mode/)
    end
    it "should fail on service type other than CY, CFS, or AIR" do
      s = shipment
      s.booking_shipment_type = 'Other'
      expect{described_class.generate_xml(s,cdefs)}.to raise_error(/Invalid service type/)
    end
    it "should translate FT2 & FTK to SFT for unit of measure" do
      s = shipment
      s.booking_lines.first.order_line.unit_of_measure = 'FT2'
      s.booking_lines.last.order_line.unit_of_measure = 'FTK'
      xml = described_class.generate_xml(s,cdefs)
      expect(xml.root.elements['booking-lines/booking-line[1]'].text('unit-of-measure')).to eq 'SFT'
      expect(xml.root.elements['booking-lines/booking-line[2]'].text('unit-of-measure')).to eq 'SFT'
    end
    it "should translate FOT to FT for unit of measure" do
      s = shipment
      s.booking_lines.first.order_line.unit_of_measure = 'FOT'
      xml = described_class.generate_xml(s,cdefs)
      expect(xml.root.elements['booking-lines/booking-line[1]'].text('unit-of-measure')).to eq 'FT'
      expect(xml.root.elements['booking-lines/booking-line[2]'].text('unit-of-measure')).to eq 'EA'
    end
  end
end
