describe OpenChain::CustomHandler::LumberLiquidators::LumberIsfShipmentXmlGenerator do

  describe 'generate_xml' do
    let :china do
      c = Country.new
      c.iso_code = 'CN'
      c
    end

    let :usa do
      c = Country.new
      c.iso_code = 'US'
      c.save!
      c
    end

    let :vendor do
      Company.new(system_code:'VCode', name:'VName')
    end

    let :importer do
      c = Company.create!(system_code: "Importer", name: "Importer")
      c.addresses.create! address_type: "ISF Importer", system_code:'IMCode', name:'IMName', line_1:'IMA1', line_2:'IMA2', line_3:'IMA3', city:'IMC', state:'IMS', postal_code:'IMP', country:usa
      c.addresses.create! address_type: "ISF Consignee", system_code:'COCode', name:'COName', line_1:'COA1', line_2:'COA2', line_3:'COA3', city:'COC', state:'COS', postal_code:'COP', country:usa
      c
    end

    let :seller do
      Address.new(system_code:'SECode', name:'SEName', line_1:'SEA1', line_2:'SEA2', line_3:'SEA3', city:'SEC', state:'SES', postal_code:'SEP', country:usa)
    end

    let :buyer do
      Address.new(system_code:'BYCode', name:'BYName', line_1:'BYA1', line_2:'BYA2', city:'BYC', state:'BYS', postal_code:'BYP', country:usa)
    end

    let :ship_to do
      Address.new(system_code:'STCode', name:'STName', line_1:'STA1', line_2:'STA2', line_3:'STA3', city:'STC', state:'STS', postal_code:'STP', country:usa)
    end

    let :consolidator do
      Address.new(system_code:'CSCode', name:'CSName', line_1:'CSA1', city:'CSC', state:'CSS', postal_code:'CSP', country:china)
    end

    let :container_stuffing do
      Address.new(system_code:'LGCode', name:'LGName', line_1:'LGA1', line_2:'LGA2', city:'LGC', state:'LGS', postal_code:'LGP', country:china)
    end

    let :ship_from do
      Address.new(system_code:'SFCode', name:'SFName', line_1:'SFA', city:'SFC', state:'SFS', postal_code:'SFP', country:china)
    end

    let :product1 do
      Product.new(unique_identifier:'0000000PROD1', name:'PNAME1')
    end

    let :product2 do
      Product.new(unique_identifier:'PROD2', name:'PNAME2')
    end

    let :order1 do
      o = Order.new(
        order_number:'ORDNUM1',
        vendor:vendor,
        importer:vendor
      )
      ol = OrderLine.new(
        line_number:1,
        product:product1
      )
      o.order_lines << ol

      o.save!
      o
    end

    let :order2 do
      o = Order.new(
        order_number:'ORDNUM2',
        vendor:vendor,
        importer:vendor
      )
      ol = OrderLine.new(
        line_number:1,
        product:product2
      )
      o.order_lines << ol

      o.save!
      o
    end

    let :shipment do
      s = Shipment.new(
        reference:'SHPREF',
        master_bill_of_lading:'ABCD2222222',
        est_departure_date:ActiveSupport::TimeZone['UTC'].parse('2016-08-31 09:10:11.345'),
        booking_number:'58363688',
        vessel: "vessel",
        voyage: "voyage",
        seller_address:seller,
        buyer_address:buyer,
        ship_to_address:ship_to,
        consolidator_address:consolidator,
        container_stuffing_address:container_stuffing,
        ship_from:ship_from,
        country_origin: china,
        consignee: importer,
        importer: importer
      )

      line_1 = ShipmentLine.new(
        line_number: 1,
        linked_order_line_id: order1.order_lines.first.id,
        product: product1
      )
      s.shipment_lines << line_1

      line_2 = ShipmentLine.new(
          line_number: 2,
          linked_order_line_id: order2.order_lines.first.id,
          product: product2
      )
      s.shipment_lines << line_2

      s.save!
      s
    end

    it "generates xml" do
      now = ActiveSupport::TimeZone['UTC'].parse('2017-01-01 10:11:12.555')
      xml = nil
      Timecop.freeze(now) do
        xml = described_class.generate_xml(shipment)
      end

      root = xml.root
      expect(root.name).to eq 'IsfEdiUpload'
      expect(root.namespace('xsi')).to eq('http://www.w3.org/2001/XMLSchema-instance')
      expect(root.namespace('isf')).to eq('http://isf.kewill.com/ws/upload/')
      expect(root.text('CUSTOMER_ACCT_CD')).to eq('VAND0323')
      expect(root.text('USER_NAME')).to eq('VAND0323')
      expect(root.text('PASSWORD')).to eq('k3w1ll')
      expect(root.text('DATE_CREATED')).to eq('2017-01-01T10:11:12')
      expect(root.text('EDI_TXN_IDENTIFIER')).to eq('168820')
      expect(root.text('ACTION_CD')).to eq('A')
      expect(root.text('ACTION_REASON_CD')).to eq('CT')
      expect(root.text('DOCUMENT_TYPE_CD')).to eq('BL')
      expect(root.text('IMPORTER_ACCT_CD')).to eq('LUMBER')
      expect(root.text('OWNER_ACCT_CD')).to eq('VAND0323')
      expect(root.text('SHIPMENT_TYPE')).to eq('01')
      expect(root.text('MOT_CD')).to eq('11')
      expect(root.text('VOAYGE_NBR')).to eq('voyage')
      expect(root.text('EST_SAIL_DATE')).to eq('2016-08-31T00:00:00')
      expect(root.text('SCAC_CD')).to eq('ABCD')
      expect(root.text('PO_NBR')).to eq('SHPREF')
      expect(root.text('BOOKING_NBR')).to eq('ORDNUM1')

      elem_edi_bill_lading = root.elements['EdiBillLading']
      expect(elem_edi_bill_lading).to_not be_nil
      expect(elem_edi_bill_lading.text('MASTER_BILL_NBR')).to eq('2222222')
      expect(elem_edi_bill_lading.text('MASTER_BILL_SCAC_CD')).to eq('ABCD')

      elem_edi_entity_arr = root.elements.to_a('EdiEntity')
      expect(elem_edi_entity_arr.size).to eq(8)

      elem_edi_entity_1 = elem_edi_entity_arr[0]
      expect(elem_edi_entity_1.text('ENTITY_TYPE_CD')).to eq('IM')
      expect(elem_edi_entity_1.text('ENTITY_ID')).to eq('IMCode')
      expect(elem_edi_entity_1.text('ENTITY_ID_TYPE_CD')).to eq('EI')
      expect(elem_edi_entity_1.text('NAME')).to eq('IMName')
      expect(elem_edi_entity_1.text('ADDRESS_1')).to eq('IMA1')
      expect(elem_edi_entity_1.text('ADDRESS_2')).to eq('IMA2')
      expect(elem_edi_entity_1.text('ADDRESS_3')).to eq('IMA3')
      expect(elem_edi_entity_1.text('CITY')).to eq('IMC')
      expect(elem_edi_entity_1.text('COUNTRY_SUBENTITY_CD')).to eq('IMS')
      expect(elem_edi_entity_1.text('POSTAL_CD')).to eq('IMP')
      expect(elem_edi_entity_1.text('COUNTRY_CD')).to eq('US')

      elem_edi_entity_2 = elem_edi_entity_arr[1]
      expect(elem_edi_entity_2.text('ENTITY_TYPE_CD')).to eq('SE')
      expect(elem_edi_entity_2.text('NAME')).to eq('SEName')
      expect(elem_edi_entity_2.text('ADDRESS_1')).to eq('SEA1')
      expect(elem_edi_entity_2.text('ADDRESS_2')).to eq('SEA2')
      expect(elem_edi_entity_2.text('ADDRESS_3')).to eq('SEA3')
      expect(elem_edi_entity_2.text('CITY')).to eq('SEC')
      expect(elem_edi_entity_2.text('COUNTRY_SUBENTITY_CD')).to eq('SES')
      expect(elem_edi_entity_2.text('POSTAL_CD')).to eq('SEP')
      expect(elem_edi_entity_2.text('COUNTRY_CD')).to eq('US')

      elem_edi_entity_3 = elem_edi_entity_arr[2]
      expect(elem_edi_entity_3.text('ENTITY_TYPE_CD')).to eq('BY')
      expect(elem_edi_entity_3.text('NAME')).to eq('BYName')
      expect(elem_edi_entity_3.text('ADDRESS_1')).to eq('BYA1')
      expect(elem_edi_entity_3.text('ADDRESS_2')).to eq('BYA2')
      expect(elem_edi_entity_3.text('ADDRESS_3')).to be_nil
      expect(elem_edi_entity_3.text('CITY')).to eq('BYC')
      expect(elem_edi_entity_3.text('COUNTRY_SUBENTITY_CD')).to eq('BYS')
      expect(elem_edi_entity_3.text('POSTAL_CD')).to eq('BYP')
      expect(elem_edi_entity_3.text('COUNTRY_CD')).to eq('US')

      elem_edi_entity_4 = elem_edi_entity_arr[3]
      expect(elem_edi_entity_4.text('ENTITY_TYPE_CD')).to eq('ST')
      expect(elem_edi_entity_4.text('NAME')).to eq('STName')
      expect(elem_edi_entity_4.text('ADDRESS_1')).to eq('STA1')
      expect(elem_edi_entity_4.text('ADDRESS_2')).to eq('STA2')
      expect(elem_edi_entity_4.text('ADDRESS_3')).to eq('STA3')
      expect(elem_edi_entity_4.text('CITY')).to eq('STC')
      expect(elem_edi_entity_4.text('COUNTRY_SUBENTITY_CD')).to eq('STS')
      expect(elem_edi_entity_4.text('POSTAL_CD')).to eq('STP')
      expect(elem_edi_entity_4.text('COUNTRY_CD')).to eq('US')

      elem_edi_entity_5 = elem_edi_entity_arr[4]
      expect(elem_edi_entity_5.text('ENTITY_TYPE_CD')).to eq('CN')
      expect(elem_edi_entity_5.text('NAME')).to eq('COName')
      expect(elem_edi_entity_5.text('ADDRESS_1')).to eq('COA1')
      expect(elem_edi_entity_5.text('ADDRESS_2')).to eq('COA2')
      expect(elem_edi_entity_5.text('ADDRESS_3')).to eq('COA3')
      expect(elem_edi_entity_5.text('CITY')).to eq('COC')
      expect(elem_edi_entity_5.text('COUNTRY_SUBENTITY_CD')).to eq('COS')
      expect(elem_edi_entity_5.text('POSTAL_CD')).to eq('COP')
      expect(elem_edi_entity_5.text('COUNTRY_CD')).to eq('US')

      elem_edi_entity_6 = elem_edi_entity_arr[5]
      expect(elem_edi_entity_6.text('ENTITY_TYPE_CD')).to eq('CS')
      expect(elem_edi_entity_6.text('NAME')).to eq('CSName')
      expect(elem_edi_entity_6.text('ADDRESS_1')).to eq('CSA1')
      expect(elem_edi_entity_6.text('ADDRESS_2')).to be_nil
      expect(elem_edi_entity_6.text('ADDRESS_3')).to be_nil
      expect(elem_edi_entity_6.text('CITY')).to eq('CSC')
      expect(elem_edi_entity_6.text('COUNTRY_SUBENTITY_CD')).to eq('CSS')
      expect(elem_edi_entity_6.text('POSTAL_CD')).to eq('CSP')
      expect(elem_edi_entity_6.text('COUNTRY_CD')).to eq('CN')

      elem_edi_entity_7 = elem_edi_entity_arr[6]
      expect(elem_edi_entity_7.text('ENTITY_TYPE_CD')).to eq('LG')
      expect(elem_edi_entity_7.text('NAME')).to eq('LGName')
      expect(elem_edi_entity_7.text('ADDRESS_1')).to eq('LGA1')
      expect(elem_edi_entity_7.text('ADDRESS_2')).to eq('LGA2')
      expect(elem_edi_entity_7.text('ADDRESS_3')).to be_nil
      expect(elem_edi_entity_7.text('CITY')).to eq('LGC')
      expect(elem_edi_entity_7.text('COUNTRY_SUBENTITY_CD')).to eq('LGS')
      expect(elem_edi_entity_7.text('POSTAL_CD')).to eq('LGP')
      expect(elem_edi_entity_7.text('COUNTRY_CD')).to eq('CN')

      elem_edi_entity_8 = elem_edi_entity_arr[7]
      expect(elem_edi_entity_8.text('ENTITY_TYPE_CD')).to eq('MF')
      expect(elem_edi_entity_8.text('ENTITY_ID')).to eq('1')
      expect(elem_edi_entity_8.text('ENTITY_ID_TYPE_CD')).to eq('EI')
      expect(elem_edi_entity_8.text('NAME')).to eq('SFName')
      expect(elem_edi_entity_8.text('ADDRESS_1')).to eq('SFA')
      expect(elem_edi_entity_8.text('ADDRESS_2')).to be_nil
      expect(elem_edi_entity_8.text('ADDRESS_3')).to be_nil
      expect(elem_edi_entity_8.text('CITY')).to eq('SFC')
      expect(elem_edi_entity_8.text('COUNTRY_SUBENTITY_CD')).to eq('SFS')
      expect(elem_edi_entity_8.text('POSTAL_CD')).to eq('SFP')
      expect(elem_edi_entity_8.text('COUNTRY_CD')).to eq('CN')

      elem_edi_line_arr = root.elements.to_a('EdiLine')
      expect(elem_edi_line_arr.size).to eq(2)

      elem_edi_line_1 = elem_edi_line_arr[0]
      expect(elem_edi_line_1.text('MFG_SUPPLIER_CD')).to eq('1')
      expect(elem_edi_line_1.text('ORIGIN_COUNTRY_CD')).to eq('CN')
      expect(elem_edi_line_1.text('PO_NBR')).to eq('ORDNUM1')
      expect(elem_edi_line_1.text('PART_CD')).to eq('PROD1')

      elem_edi_line_2 = elem_edi_line_arr[1]
      expect(elem_edi_line_2.text('MFG_SUPPLIER_CD')).to eq('1')
      expect(elem_edi_line_2.text('PO_NBR')).to eq('ORDNUM2')
      expect(elem_edi_line_2.text('PART_CD')).to eq('PROD2')
    end

    it "handles missing address content, est load date, master bill" do
      shipment.update_attributes!(master_bill_of_lading:nil, est_load_date:nil, seller_address:nil, buyer_address:nil, ship_to_address:nil, consolidator_address:nil, container_stuffing_address:nil, ship_from:nil, importer:nil, consignee:nil)

      xml = described_class.generate_xml(shipment)
      root = xml.root
      expect(root.text('EST_LOAD_DATE')).to be_nil
      expect(root.text('SCAC_CD')).to be_nil
      expect(root.elements['EdiBillLading']).to be_nil

      elem_edi_entity_arr = root.elements.to_a('EdiEntity')
      expect(elem_edi_entity_arr.size).to eq(0)
    end

    it "handles missing order lines, countries" do
      seller.update_attributes!(country:nil)

      shipment.shipment_lines.each do |shipment_line|
        shipment_line.order_lines.delete_all
      end

      xml = described_class.generate_xml(shipment)
      root = xml.root
      elem_shipping_order = root.elements['ShippingOrder']

      elem_edi_line_arr = root.elements.to_a('EdiLine')
      expect(elem_edi_line_arr.size).to eq(0)

      elem_edi_entity_arr = root.elements.to_a('EdiEntity')

      elem_edi_entity_1 = elem_edi_entity_arr[0]
      expect(elem_edi_entity_1.text('ENTITY_TYPE_CD')).to eq('IM')

      elem_edi_entity_2 = elem_edi_entity_arr[1]
      expect(elem_edi_entity_2.text('ENTITY_TYPE_CD')).to eq('SE')
      expect(elem_edi_entity_2.text('CountryName')).to be_nil
    end

    it "handles replacement ISF" do
      sync = SyncRecord.new(trading_partner: 'ISF')
      shipment.sync_records << sync
      shipment.save!

      xml = described_class.generate_xml(shipment)
      root = xml.root
      expect(root.text('ACTION_CD')).to eq('R')
    end

    it "handles short master bill" do
      shipment.update_attributes!(master_bill_of_lading:'X')

      xml = described_class.generate_xml(shipment)
      root = xml.root
      expect(root.text('SCAC_CD')).to eq('X')

      elem_edi_bill_lading = root.elements['EdiBillLading']
      expect(elem_edi_bill_lading).to_not be_nil
      expect(elem_edi_bill_lading.text('MASTER_BILL_NBR')).to be_nil
      expect(elem_edi_bill_lading.text('MASTER_BILL_SCAC_CD')).to eq('X')
    end
  end

end