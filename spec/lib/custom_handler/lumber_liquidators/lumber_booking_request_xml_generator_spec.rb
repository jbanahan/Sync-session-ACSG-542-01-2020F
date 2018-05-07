require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberBookingRequestXmlGenerator do

  describe 'generate_xml' do
    let :china do
      c = Country.new
      c.iso_code = 'CN'
      c.name = 'China'
      c
    end

    let :usa do
      c = Country.new
      c.iso_code = 'US'
      c.name = 'United Schtates'
      c
    end

    let :vendor do
      Company.new(system_code:'VCode',name:'VName')
    end

    let :ship_from do
      Address.new(system_code:'SFCode',name:'SFName',line_1:'SFA',city:'SFC',state:'SFS',postal_code:'SFP',country:china)
    end

    let :ship_to do
      Address.new(system_code:'STCode',name:'STName',line_1:'STA1',line_2:'STA2',line_3:'STA3',city:'STC',state:'STS',postal_code:'STP',country:usa)
    end

    let :product1 do
      # Zero padding should be ignored/stripped.
      Product.new(unique_identifier:'00000PROD1',name:'PNAME1')
    end

    let :product2 do
      Product.new(unique_identifier:'PROD2',name:'PNAME2')
    end

    let :order1 do
      o = Order.new(
        order_number:'ORDNUM1',
        fob_point:'BRIOA',
        vendor:vendor,
        importer:vendor
      )
      ol = OrderLine.new(
        line_number:1,
        product:product1,
        unit_of_measure:'LBR',
        ship_to:ship_to
      )
      o.order_lines << ol

      o.save!
      o
    end

    let :order2 do
      o = Order.new(
        order_number:'ORDNUM2',
        fob_point:'BRIOB',
        vendor:vendor,
        importer:vendor
      )
      ol = OrderLine.new(
        line_number:1,
        product:product2,
        unit_of_measure:'FT',
        ship_to:ship_to
      )
      o.order_lines << ol

      o.save!
      o
    end

    let :shipment do
      user = User.new(first_name:'Bjork', last_name:'Eyjafjallajokull')

      s = Shipment.new(
        reference:'SHPREF',
        cargo_ready_date:ActiveSupport::TimeZone['UTC'].parse('2016-08-31 09:10:11.345'),
        booking_shipment_type:'CY',
        booking_mode:'Air',
        requested_equipment:"2 20STD\n3 40HQ",
        vendor:vendor,
        ship_from:ship_from,
        booking_requested_by:user
      )

      b1 = BookingLine.new(
        line_number: 1,
        order_line: order1.order_lines.first,
        quantity: 50.25,
        gross_kgs: 99.88,
        cbms: 1.23
      )
      s.booking_lines << b1

      b2 = BookingLine.new(
        line_number: 2,
        order_line: order2.order_lines.first,
        quantity: 75.55,
        gross_kgs: 88.99,
        cbms: 4.56
      )
      s.booking_lines << b2

      s.save!
      s
    end

    it "generates xml" do
      xref_uom_1 = DataCrossReference.create! key:'LBR', value:'LBS', cross_reference_type: DataCrossReference::LL_GTN_QUANTITY_UOM
      xref_uom_2 = DataCrossReference.create! key:'FT', value:'FTQTY', cross_reference_type: DataCrossReference::LL_GTN_QUANTITY_UOM
      xref_equip_1 = DataCrossReference.create! key:'20STD', value:'D20', cross_reference_type: DataCrossReference::LL_GTN_EQUIPMENT_TYPE
      xref_equip_2 = DataCrossReference.create! key:'40HQ', value:'HC40', cross_reference_type: DataCrossReference::LL_GTN_EQUIPMENT_TYPE

      now = ActiveSupport::TimeZone['UTC'].parse('2017-01-01 10:11:12.555')
      Timecop.freeze(now) do
        xml = described_class.generate_xml(shipment)
        root = xml.root
        expect(root.name).to eq 'ShippingOrderMessage'

        elem_transaction_info = root.elements['TransactionInfo']
        expect(elem_transaction_info).to_not be_nil
        expect(elem_transaction_info.text('MessageSender')).to eq('ACSVFILLQ')
        expect(elem_transaction_info.text('MessageRecipient')).to eq('ACSVFILLQ')
        expect(elem_transaction_info.text('MessageID')).to eq('20170101101112555')
        expect(elem_transaction_info.text('Created')).to eq('2017-01-01T10:11:12.555')
        expect(elem_transaction_info.text('FileName')).to eq('Lumber_SHPREF.xml')
        expect(elem_transaction_info.text('MessageOriginator')).to eq('ACSVFILLQ')

        elem_shipping_order = root.elements['ShippingOrder']
        expect(elem_shipping_order).to_not be_nil
        expect(elem_shipping_order.attributes['ShippingOrderNumber']).to eq('SHPREF')
        expect(elem_shipping_order.text('Purpose')).to eq('Create')
        expect(elem_shipping_order.text('ShippingOrderNumber')).to eq('SHPREF')
        expect(elem_shipping_order.text('Status')).to eq('Submitted')
        expect(elem_shipping_order.text('CargoReadyDate')).to eq('2016-08-31T09:10:11.345')
        expect(elem_shipping_order.text('CommercialInvoiceNumber')).to eq('N/A')
        expect(elem_shipping_order.text('LoadType')).to eq('CY')
        expect(elem_shipping_order.text('TransportationMode')).to eq('Air')
        expect(elem_shipping_order.text('Division')).to eq('LLIQ')
        expect(elem_shipping_order.text('UserDefinedReferenceField1')).to eq('Bjork Eyjafjallajokull')

        elem_port_of_loading = elem_shipping_order.elements['PortOfLoading']
        expect(elem_port_of_loading).to_not be_nil
        elem_city_code = elem_port_of_loading.elements['CityCode']
        expect(elem_city_code).to_not be_nil
        expect(elem_city_code.text).to eq('BRIOA')
        expect(elem_city_code.attributes['Qualifier']).to eq('UN')

        elem_item_arr = elem_shipping_order.elements.to_a('Item')
        expect(elem_item_arr.size).to eq(2)

        elem_item_1 = elem_item_arr[0]
        expect(elem_item_1.text('Division')).to eq('LLIQ')
        expect(elem_item_1.text('PurchaseOrderNumber')).to eq('ORDNUM1')
        expect(elem_item_1.text('ItemNumber')).to eq('PROD1')
        expect(elem_item_1.text('CommodityDescription')).to eq('PNAME1')
        elem_total_gross_weight = elem_item_1.elements['TotalGrossWeight']
        expect(elem_total_gross_weight).not_to be_nil
        expect(elem_total_gross_weight.text).to eq('99.88')
        expect(elem_total_gross_weight.attributes['Unit']).to eq('KG')
        expect(elem_item_1.text "TotalCubicMeters").to eq "1.23"
        elem_quantity = elem_item_1.elements['Quantity']
        expect(elem_quantity).not_to be_nil
        expect(elem_quantity.text).to eq('50.25')
        expect(elem_quantity.attributes['ANSICode']).to eq('LBS')
        expect(elem_item_1.text('POLineNumber')).to eq('1')

        elem_item_2 = elem_item_arr[1]
        expect(elem_item_2.text('PurchaseOrderNumber')).to eq('ORDNUM2')
        expect(elem_item_2.text('ItemNumber')).to eq('PROD2')
        expect(elem_item_2.text('CommodityDescription')).to eq('PNAME2')
        expect(elem_item_2.text('TotalGrossWeight')).to eq('88.99')
        expect(elem_item_2.text "TotalCubicMeters").to eq "4.56"
        elem_quantity_2 = elem_item_2.elements['Quantity']
        expect(elem_quantity_2).not_to be_nil
        expect(elem_quantity_2.text).to eq('75.55')
        expect(elem_quantity_2.attributes['ANSICode']).to eq('FTQTY')
        expect(elem_item_2.text('POLineNumber')).to eq('1')

        elem_equipment_arr = elem_shipping_order.elements.to_a('Equipment')
        expect(elem_equipment_arr.size).to eq(2)

        elem_equipment_1 = elem_equipment_arr[0]
        expect(elem_equipment_1.text('Code')).to eq('D20')
        expect(elem_equipment_1.text('Type')).to eq('20STD')
        expect(elem_equipment_1.text('Quantity')).to eq('2')

        elem_equipment_2 = elem_equipment_arr[1]
        expect(elem_equipment_2.text('Code')).to eq('HC40')
        expect(elem_equipment_2.text('Type')).to eq('40HQ')
        expect(elem_equipment_2.text('Quantity')).to eq('3')

        elem_party_arr = elem_shipping_order.elements.to_a('PartyInfo')
        expect(elem_party_arr.size).to eq(3)

        elem_party_1 = elem_party_arr[0]
        expect(elem_party_1.text('Type')).to eq('Supplier')
        expect(elem_party_1.text('Code')).to eq('VCode')
        expect(elem_party_1.text('Name')).to eq('VName')
        # Supplier has no address.
        expect(elem_party_1.elements['AddressLine1']).to be_nil

        elem_party_2 = elem_party_arr[1]
        expect(elem_party_2.text('Type')).to eq('Factory')
        expect(elem_party_2.text('Code')).to eq(ship_from.id.to_s)
        expect(elem_party_2.text('Name')).to eq('SFName')
        expect(elem_party_2.text('AddressLine1')).to eq('SFA')
        expect(elem_party_2.text('AddressLine2')).to be_nil
        expect(elem_party_2.text('AddressLine3')).to be_nil
        expect(elem_party_2.text('CityName')).to eq('SFC')
        expect(elem_party_2.text('State')).to eq('SFS')
        expect(elem_party_2.text('PostalCode')).to eq('SFP')
        expect(elem_party_2.text('CountryName')).to eq('China')

        elem_party_3 = elem_party_arr[2]
        expect(elem_party_3.text('Type')).to eq('ShipTo')
        expect(elem_party_3.text('Code')).to eq('STCode')
        expect(elem_party_3.text('Name')).to eq('STName')
        expect(elem_party_3.text('AddressLine1')).to eq('STA1')
        expect(elem_party_3.text('AddressLine2')).to eq('STA2')
        expect(elem_party_3.text('AddressLine3')).to eq('STA3')
        expect(elem_party_3.text('CityName')).to eq('STC')
        expect(elem_party_3.text('State')).to eq('STS')
        expect(elem_party_3.text('PostalCode')).to eq('STP')
        expect(elem_party_3.text('CountryName')).to eq('United Schtates')
      end
    end

    it "handles missing address content, xrefs, nil-sensitive shipment data, order FOB point" do
      shipment.update_attributes!(cargo_ready_date:nil,ship_from:nil,vendor:nil,booking_requested_by:nil,requested_equipment:nil)

      order1.update_attributes!(fob_point:nil)
      order1.order_lines.first.update_attributes!(ship_to:nil)

      xml = described_class.generate_xml(shipment)
      root = xml.root
      elem_shipping_order = root.elements['ShippingOrder']
      expect(elem_shipping_order.text('ShippingOrderNumber')).to eq('SHPREF')
      expect(elem_shipping_order.text('CargoReadyDate')).to be_nil
      expect(elem_shipping_order.text('UserDefinedReferenceField1')).to be_nil

      elem_port_of_loading = elem_shipping_order.elements['PortOfLoading']
      expect(elem_port_of_loading).to be_nil

      elem_item_arr = elem_shipping_order.elements.to_a('Item')
      expect(elem_item_arr.size).to eq(2)

      elem_item_1 = elem_item_arr[0]
      expect(elem_item_1.text('PurchaseOrderNumber')).to eq('ORDNUM1')
      elem_quantity = elem_item_1.elements['Quantity']
      expect(elem_quantity.text).to eq('50.25')
      expect(elem_quantity.attributes['ANSICode']).to be_nil

      elem_equipment_arr = elem_shipping_order.elements.to_a('Equipment')
      expect(elem_equipment_arr.size).to eq(0)

      elem_party_arr = elem_shipping_order.elements.to_a('PartyInfo')
      expect(elem_party_arr.size).to eq(0)
    end

    it "handles missing orders, order lines, products, country" do
      ship_from.update_attributes!(country:nil)

      shipment.booking_lines.each do |booking_line|
        booking_line.update_attributes!(order_line:nil,order:nil,product:nil)
      end

      xml = described_class.generate_xml(shipment)
      root = xml.root
      elem_shipping_order = root.elements['ShippingOrder']

      elem_port_of_loading = elem_shipping_order.elements['PortOfLoading']
      expect(elem_port_of_loading).to be_nil

      elem_item_arr = elem_shipping_order.elements.to_a('Item')
      expect(elem_item_arr.size).to eq(2)

      elem_item_1 = elem_item_arr[0]
      expect(elem_item_1.text('PurchaseOrderNumber')).to be_nil
      expect(elem_item_1.text('ItemNumber')).to be_nil
      expect(elem_item_1.text('CommodityDescription')).to be_nil
      expect(elem_item_1.text('POLineNumber')).to be_nil

      elem_party_arr = elem_shipping_order.elements.to_a('PartyInfo')
      expect(elem_party_arr.size).to eq(2)

      elem_party_1 = elem_party_arr[0]
      expect(elem_party_1.text('Type')).to eq('Supplier')

      elem_party_2 = elem_party_arr[1]
      expect(elem_party_2.text('Type')).to eq('Factory')
      expect(elem_party_2.text('CountryName')).to be_nil
    end

    it "handles missing booking lines" do
      shipment.booking_lines.delete_all

      xml = described_class.generate_xml(shipment)
      root = xml.root
      elem_shipping_order = root.elements['ShippingOrder']

      elem_port_of_loading = elem_shipping_order.elements['PortOfLoading']
      expect(elem_port_of_loading).to be_nil

      elem_item_arr = elem_shipping_order.elements.to_a('Item')
      expect(elem_item_arr.size).to eq(0)

      elem_party_arr = elem_shipping_order.elements.to_a('PartyInfo')
      expect(elem_party_arr.size).to eq(2)

      elem_party_1 = elem_party_arr[0]
      expect(elem_party_1.text('Type')).to eq('Supplier')

      elem_party_2 = elem_party_arr[1]
      expect(elem_party_2.text('Type')).to eq('Factory')
    end
  end

end