describe OpenChain::CustomHandler::LumberLiquidators::LumberFactoryBotPackCsvGenerator do

  describe 'generate_csv' do
    let :vendor_address do
      china = FactoryBot(:country, iso_code: "CN", name: "China")
      addr = Address.new(system_code:'VCode-CORP', name:'Corporate', line_1:'VA', city:'VC', state:'VS', postal_code:'VP', country:china)
      addr.save!
      addr
    end

    let :vendor do
      vendor = Company.new(system_code:'VCode', name:'VName')
      vendor.save!
      vendor_address.company_id = vendor.id
      vendor_address.save!
      vendor
    end

    let :product1 do
      Product.new(unique_identifier:'PROD1', name:'PNAME1')
    end

    let :product2 do
      Product.new(unique_identifier:'0000PROD2', name:'PNAME2')
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
        line_number:3,
        product:product2
      )
      o.order_lines << ol

      o.save!
      o
    end

    let :shipment do
      s = Shipment.new(
        reference: 'SHPREF',
        vendor: vendor,
        booking_number: 'ABC54321',
        booking_vessel: 'SS Minnow',
        booking_voyage: '26269abc',
        importer_reference: 'arfarf'
      )

      port_loading = FactoryBot(:port, name: 'Hong Kong', unlocode: "HKHKG")
      port_delivery = FactoryBot(:port, name: 'Long Beach, CA', unlocode: "USLGB")

      container = Container.new(
        port_of_loading_id: port_loading.id,
        port_of_delivery_id: port_delivery.id,
        container_number: 'AAAA13579',
        container_size: '50ft',
        seal_number: '68373799',
        container_pickup_date: ActiveSupport::TimeZone['UTC'].parse('2016-08-31 09:10:11'),
        container_return_date: ActiveSupport::TimeZone['UTC'].parse('2017-07-31 08:09:10')
      )
      s.containers << container

      line_1 = ShipmentLine.new(
        container: container,
        linked_order_line_id: order1.order_lines.first.id,
        product:product1,
        carton_qty: 5,
        quantity: 20,
        cbms: 10.5,
        gross_kgs: 11.25
      )
      s.shipment_lines << line_1

      line_2 = ShipmentLine.new(
        container: container,
        linked_order_line_id: order2.order_lines.first.id,
        product:product2,
        carton_qty: 3,
        quantity: 22,
        cbms: 3.5,
        gross_kgs: 4.5
      )
      s.shipment_lines << line_2

      s.save!
      s
    end

    it "generates csv" do
      now = ActiveSupport::TimeZone['UTC'].parse('2017-01-01 10:11:12')
      csv = nil
      Timecop.freeze(now) do
        csv = CSV.parse(described_class.generate_csv(shipment))
      end

      expect(csv.length).to eq(3)

      # Header line
      expect(csv[0][0]).to eq('Version')
      expect(csv[0][1]).to eq('Document Created Date Time')
      expect(csv[0][2]).to eq('Shipper Name')
      expect(csv[0][3]).to eq('Shipper Address')
      expect(csv[0][4]).to eq('Shipper City')
      expect(csv[0][5]).to eq('Shipper State')
      expect(csv[0][6]).to eq('Shipper Postal Code')
      expect(csv[0][7]).to eq('Shipper Country')
      expect(csv[0][8]).to eq('Carrier Booking Number')
      expect(csv[0][9]).to eq('Vessel')
      expect(csv[0][10]).to eq('Voyage')
      expect(csv[0][11]).to eq('Port of Loading')
      expect(csv[0][12]).to eq('Port of Delivery')
      expect(csv[0][13]).to eq('Shipment Plan Number')
      expect(csv[0][14]).to eq('Container Number')
      expect(csv[0][15]).to eq('Container Size')
      expect(csv[0][16]).to eq('Seal Number')
      expect(csv[0][17]).to eq('Container Pickup Date')
      expect(csv[0][18]).to eq('Container Return Date')
      expect(csv[0][19]).to eq('PO Number')
      expect(csv[0][20]).to eq('Item')
      expect(csv[0][21]).to eq('Line Item ID')
      expect(csv[0][22]).to eq('Description')
      expect(csv[0][23]).to eq('Cartons')
      expect(csv[0][24]).to eq('Pieces')
      expect(csv[0][25]).to eq('CBM')
      expect(csv[0][26]).to eq('Gross Weight KGS')
      expect(csv[0][27]).to eq('Remark')
      expect(csv[0][28]).to eq('Container Total Cartons')
      expect(csv[0][29]).to eq('Container Total Pieces')
      expect(csv[0][30]).to eq('Container Total CBM')
      expect(csv[0][31]).to eq('Container Total KGS')

      # Line 1
      expect(csv[1][0]).to eq('Original')
      expect(csv[1][1]).to eq('20170101101112')
      expect(csv[1][2]).to eq('VName')
      expect(csv[1][3]).to eq('VA')
      expect(csv[1][4]).to eq('VC')
      expect(csv[1][5]).to eq('VS')
      expect(csv[1][6]).to eq('VP')
      expect(csv[1][7]).to eq('CN')
      expect(csv[1][8]).to eq('ABC54321')
      expect(csv[1][9]).to eq('SS Minnow')
      expect(csv[1][10]).to eq('26269abc')
      expect(csv[1][11]).to eq('HKHKG')
      expect(csv[1][12]).to eq('USLGB')
      expect(csv[1][13]).to eq('arfarf')
      expect(csv[1][14]).to eq('AAAA13579')
      expect(csv[1][15]).to eq('50ft')
      expect(csv[1][16]).to eq('68373799')
      expect(csv[1][17]).to eq('20160831')
      expect(csv[1][18]).to eq('20170731')
      expect(csv[1][19]).to eq('ORDNUM1')
      expect(csv[1][20]).to eq('PROD1')
      expect(csv[1][21]).to eq('1')
      expect(csv[1][22]).to eq('PNAME1')
      expect(csv[1][23]).to eq('5')
      expect(csv[1][24]).to eq('20.0')
      expect(csv[1][25]).to eq('10.5')
      expect(csv[1][26]).to eq('11.25')
      expect(csv[1][27]).to be_nil
      expect(csv[1][28]).to eq('8')
      expect(csv[1][29]).to eq('42.0')
      expect(csv[1][30]).to eq('14.0')
      expect(csv[1][31]).to eq('15.75')

      # Line 2
      expect(csv[2][0]).to eq('Original')
      expect(csv[2][1]).to eq('20170101101112')
      expect(csv[2][2]).to eq('VName')
      expect(csv[2][3]).to eq('VA')
      expect(csv[2][4]).to eq('VC')
      expect(csv[2][5]).to eq('VS')
      expect(csv[2][6]).to eq('VP')
      expect(csv[2][7]).to eq('CN')
      expect(csv[2][8]).to eq('ABC54321')
      expect(csv[2][9]).to eq('SS Minnow')
      expect(csv[2][10]).to eq('26269abc')
      expect(csv[2][11]).to eq('HKHKG')
      expect(csv[2][12]).to eq('USLGB')
      expect(csv[2][13]).to eq('arfarf')
      expect(csv[2][14]).to eq('AAAA13579')
      expect(csv[2][15]).to eq('50ft')
      expect(csv[2][16]).to eq('68373799')
      expect(csv[2][17]).to eq('20160831')
      expect(csv[2][18]).to eq('20170731')
      expect(csv[2][19]).to eq('ORDNUM2')
      expect(csv[2][20]).to eq('PROD2')
      expect(csv[2][21]).to eq('3')
      expect(csv[2][22]).to eq('PNAME2')
      expect(csv[2][23]).to eq('3')
      expect(csv[2][24]).to eq('22.0')
      expect(csv[2][25]).to eq('3.5')
      expect(csv[2][26]).to eq('4.5')
      expect(csv[2][27]).to be_nil
      expect(csv[2][28]).to eq('8')
      expect(csv[2][29]).to eq('42.0')
      expect(csv[2][30]).to eq('14.0')
      expect(csv[2][31]).to eq('15.75')
    end

    it "handles missing vendor and container" do
      shipment.update_attributes! vendor_id: nil
      shipment.shipment_lines.each do |shipment_line|
        shipment_line.update_attributes! container_id: nil
      end
      shipment.reload
      shipment.containers.destroy_all
      csv = CSV.parse(described_class.generate_csv(shipment))

      expect(csv[1][0]).to eq('Original')
      expect(csv[1][2]).to be_nil
      expect(csv[1][3]).to be_nil
      expect(csv[1][4]).to be_nil
      expect(csv[1][5]).to be_nil
      expect(csv[1][6]).to be_nil
      expect(csv[1][7]).to be_nil
      expect(csv[1][8]).to eq('ABC54321')
      expect(csv[1][9]).to eq('SS Minnow')
      expect(csv[1][10]).to eq('26269abc')
      expect(csv[1][11]).to be_nil
      expect(csv[1][12]).to be_nil
      expect(csv[1][13]).to eq('arfarf')
      expect(csv[1][14]).to be_nil
      expect(csv[1][15]).to be_nil
      expect(csv[1][16]).to be_nil
      expect(csv[1][17]).to be_nil
      expect(csv[1][18]).to be_nil
      expect(csv[1][19]).to eq('ORDNUM1')
      expect(csv[1][20]).to eq('PROD1')
      expect(csv[1][21]).to eq('1')
      expect(csv[1][22]).to eq('PNAME1')
      expect(csv[1][23]).to eq('5')
      expect(csv[1][24]).to eq('20.0')
      expect(csv[1][25]).to eq('10.5')
      expect(csv[1][26]).to eq('11.25')
      expect(csv[1][27]).to be_nil
      expect(csv[1][28]).to eq('0')
      expect(csv[1][29]).to eq('0')
      expect(csv[1][30]).to eq('0')
      expect(csv[1][31]).to eq('0')
    end

    it "handles missing ports, vendor address and dates" do
      shipment.containers.each do |container|
        container.container_pickup_date = nil
        container.container_return_date = nil
        container.port_of_loading = nil
        container.port_of_delivery = nil
      end

      vendor_address.company_id = nil
      vendor_address.save!

      csv = CSV.parse(described_class.generate_csv(shipment))

      expect(csv[1][0]).to eq('Original')
      expect(csv[1][2]).to eq('VName')
      expect(csv[1][3]).to be_nil
      expect(csv[1][4]).to be_nil
      expect(csv[1][5]).to be_nil
      expect(csv[1][6]).to be_nil
      expect(csv[1][7]).to be_nil
      expect(csv[1][8]).to eq('ABC54321')
      expect(csv[1][9]).to eq('SS Minnow')
      expect(csv[1][10]).to eq('26269abc')
      expect(csv[1][11]).to be_nil
      expect(csv[1][12]).to be_nil
      expect(csv[1][13]).to eq('arfarf')
      expect(csv[1][14]).to eq('AAAA13579')
      expect(csv[1][15]).to eq('50ft')
      expect(csv[1][16]).to eq('68373799')
      expect(csv[1][17]).to be_nil
      expect(csv[1][18]).to be_nil
      expect(csv[1][19]).to eq('ORDNUM1')
      expect(csv[1][20]).to eq('PROD1')
      expect(csv[1][21]).to eq('1')
      expect(csv[1][22]).to eq('PNAME1')
      expect(csv[1][23]).to eq('5')
      expect(csv[1][24]).to eq('20.0')
      expect(csv[1][25]).to eq('10.5')
      expect(csv[1][26]).to eq('11.25')
      expect(csv[1][27]).to be_nil
      expect(csv[1][28]).to eq('8')
      expect(csv[1][29]).to eq('42.0')
      expect(csv[1][30]).to eq('14.0')
      expect(csv[1][31]).to eq('15.75')
    end

    it "handles missing vendor address country" do
      vendor_address.country = nil
      vendor_address.save!

      csv = CSV.parse(described_class.generate_csv(shipment))

      expect(csv[1][0]).to eq('Original')
      expect(csv[1][2]).to eq('VName')
      expect(csv[1][3]).to eq('VA')
      expect(csv[1][4]).to eq('VC')
      expect(csv[1][5]).to eq('VS')
      expect(csv[1][6]).to eq('VP')
      expect(csv[1][7]).to be_nil
      expect(csv[1][8]).to eq('ABC54321')
      expect(csv[1][9]).to eq('SS Minnow')
      expect(csv[1][10]).to eq('26269abc')
      expect(csv[1][11]).to eq('HKHKG')
      expect(csv[1][12]).to eq('USLGB')
      expect(csv[1][13]).to eq('arfarf')
      expect(csv[1][14]).to eq('AAAA13579')
      expect(csv[1][15]).to eq('50ft')
      expect(csv[1][16]).to eq('68373799')
      expect(csv[1][17]).to eq('20160831')
      expect(csv[1][18]).to eq('20170731')
      expect(csv[1][19]).to eq('ORDNUM1')
      expect(csv[1][20]).to eq('PROD1')
      expect(csv[1][21]).to eq('1')
      expect(csv[1][22]).to eq('PNAME1')
      expect(csv[1][23]).to eq('5')
      expect(csv[1][24]).to eq('20.0')
      expect(csv[1][25]).to eq('10.5')
      expect(csv[1][26]).to eq('11.25')
      expect(csv[1][27]).to be_nil
      expect(csv[1][28]).to eq('8')
      expect(csv[1][29]).to eq('42.0')
      expect(csv[1][30]).to eq('14.0')
      expect(csv[1][31]).to eq('15.75')
    end

    it "generates revised csv" do
      sync = SyncRecord.new(trading_partner: 'FactoryBot Pack Declaration')
      shipment.sync_records << sync

      csv = CSV.parse(described_class.generate_csv(shipment))

      expect(csv[1][0]).to eq('Revised')
      expect(csv[1][2]).to eq('VName')
      expect(csv[1][8]).to eq('ABC54321')
    end
  end
end