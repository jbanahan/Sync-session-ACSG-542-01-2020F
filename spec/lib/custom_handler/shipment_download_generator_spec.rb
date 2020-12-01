describe OpenChain::CustomHandler::ShipmentDownloadGenerator do

  def create_lines shipment, order, line_count = 1, container = nil
    product = FactoryBot(:product, importer: FactoryBot(:importer))
    @cdefs ||= subject.class.prep_custom_definitions([:prod_part_number])
    product.update_custom_value!(@cdefs[:prod_part_number], "Part")

    line_count.times do
      line = FactoryBot(:shipment_line, shipment:shipment, product:product, container:container, carton_qty:20, quantity:100, cbms:5, gross_kgs: 20)
      order_line = FactoryBot(:order_line, order:order, quantity:line.quantity, product:product, country_of_origin:'GN')
      PieceSet.create(order_line:order_line, quantity:line.quantity, shipment_line:line)
    end
    shipment.reload
  end

  let (:user) { FactoryBot(:master_user) }
  let (:shipment) {
    s = FactoryBot(:shipment, receipt_location: 'Prague, CZK', destination_port: FactoryBot(:port), final_dest_port: FactoryBot(:port),
      master_bill_of_lading: 'MASTER', house_bill_of_lading: 'HOUSE', vessel: 'La Fromage Du Mer',
      voyage: '20000 Leagues', booking_received_date: 1.week.ago, cargo_on_hand_date: 3.days.ago,
      docs_received_date: 2.days.ago, confirmed_on_board_origin_date: 1.day.ago, departure_date: 10.days.ago,
      eta_last_foreign_port_date: 9.days.ago, departure_last_foreign_port_date: 8.days.ago,
      est_arrival_port_date: 7.days.ago, freight_terms: "FOB", shipment_type: "TYPE")
    # this is a bit of a copout, but the reload strips the sub-seconds added above since the db field only stores to seconds
    s.reload
    s
  }
  let (:cdefs) {
    subject.send(:cdefs)
  }


  describe "generate" do
    let (:builder) { XlsxBuilder.new }

    context "with no containers" do
      it 'only has one sheet with header information for ocean shipments' do
        subject.generate(builder, shipment, user)

        data = XlsxTestReader.new(builder).raw_workbook_data
        expect(data.keys).to eq ["Details"]

        sheet = data["Details"]
        expect(sheet[0]).to eq ["Freight Receipt Location", "Discharge Port Name", "Final Destination Name", "Master Bill of Lading", "House Bill of Lading", "Vessel", "Voyage"]
        expect(sheet[1]).to eq [shipment.receipt_location, shipment.destination_port.name, shipment.final_dest_port.name, shipment.master_bill_of_lading, shipment.house_bill_of_lading, shipment.vessel, shipment.voyage]
        expect(sheet[2]).to eq ["Confirmed On Board Origin Date", "Departure Date", "ETA Last Origin Port Date", "Departure Last Origin Port Date", "Est Arrival Discharge", nil, nil]
        expect(sheet[3]).to eq [shipment.confirmed_on_board_origin_date, shipment.departure_date, shipment.eta_last_foreign_port_date, shipment.departure_last_foreign_port_date, shipment.est_arrival_port_date]
      end

      it "includes line details for air shipments" do
        shipment.update_attributes! mode: "AIR"
        order = FactoryBot(:order, customer_order_number:'123456789', ship_window_end: 2.days.ago, first_expected_delivery_date: 1.month.from_now)
        create_lines shipment, order, 1, nil

        subject.generate(builder, shipment, user)

        data = XlsxTestReader.new(builder).raw_workbook_data
        expect(data.keys).to eq ["Details"]
        sheet = data["Details"]

        expect(sheet[1]).to eq [shipment.receipt_location, shipment.destination_port.name, shipment.final_dest_port.name, shipment.master_bill_of_lading, shipment.house_bill_of_lading, shipment.vessel, shipment.voyage]
        expect(sheet[3]).to eq [shipment.confirmed_on_board_origin_date, shipment.departure_date, shipment.eta_last_foreign_port_date, shipment.departure_last_foreign_port_date, shipment.est_arrival_port_date]

        line = shipment.shipment_lines.first

        row = sheet[7]
        expect(row.first(9)).to eq [nil, order.customer_order_number, "Part", order.vendor.name, line.carton_qty, line.quantity, line.cbms, line.chargeable_weight, line.gross_kgs]
        expect(row[9].to_date).to eq order.ship_window_end.to_date
        expect(row[10..11]).to eq [shipment.freight_terms, shipment.shipment_type]
        expect(row[12].to_date).to eq order.first_expected_delivery_date.to_date
        expect(row[13].to_date).to eq shipment.booking_received_date.to_date
        expect(row[14].to_date).to eq shipment.cargo_on_hand_date.to_date
        expect(row[15].to_date).to eq shipment.docs_received_date.to_date

        expect(sheet[8]).to eq [nil, nil, nil, "Totals:", 20, 100, 5, 833.33, 20]
      end
    end

    context "with containers" do
      let! (:container1) { FactoryBot :container, shipment: shipment, container_number: '99000', seal_number: 'SEAL1212', container_size: 'GINORMOUS' }
      let! (:container2) { FactoryBot :container, shipment: shipment, container_number: 'CONT2'}
      let! (:order) { FactoryBot(:order, customer_order_number:'123456789', ship_window_end: 2.days.ago.to_date, first_expected_delivery_date: 1.month.from_now.to_date) }

      before :each do
        create_lines shipment, order, 3, container1
      end

      it 'creates a sheet for each container' do
        subject.generate(builder, shipment, user)

        data = XlsxTestReader.new(builder).raw_workbook_data
        expect(data.keys).to eq ["99000", "CONT2"]
        sheet = data["99000"]

        expect(sheet[0]).to eq ["Freight Receipt Location", "Discharge Port Name", "Final Destination Name", "Master Bill of Lading", "House Bill of Lading", "Vessel", "Voyage", "Container Number", "Size", "Seal Number"]
        expect(sheet[1]).to eq [shipment.receipt_location, shipment.destination_port.name, shipment.final_dest_port.name, shipment.master_bill_of_lading, shipment.house_bill_of_lading, shipment.vessel, shipment.voyage, container1.container_number, container1.container_size, container1.seal_number]
        expect(sheet[2]).to eq ["Confirmed On Board Origin Date", "Departure Date", "ETA Last Origin Port Date", "Departure Last Origin Port Date", "Est Arrival Discharge", nil, nil, nil, nil, nil]
        expect(sheet[3]).to eq [shipment.confirmed_on_board_origin_date, shipment.departure_date, shipment.eta_last_foreign_port_date, shipment.departure_last_foreign_port_date, shipment.est_arrival_port_date]

        expect(sheet[6]).to eq ["Container Number", "Customer Order Number", "Part Number", "Vendor Name", "Cartons", "Quantity Shipped", "Volume (CBMS)", "Chargeable Weight (KGS)", "Gross Weight (KGS)", "Ship Window End Date", "Freight Terms", "Shipment Type", "First Expected Delivery Date", "Booking Received Date", "Cargo On Hand Date", "Docs Received Date"]
        shipment.shipment_lines.each_with_index do |line, idx|
          row = sheet[7 + idx]
          expect(row.first(9)).to eq [container1.container_number, order.customer_order_number, "Part", order.vendor.name, line.carton_qty, line.quantity, line.cbms, line.chargeable_weight, line.gross_kgs]
          expect(row[9].to_date).to eq order.ship_window_end.to_date
          expect(row[10..11]).to eq [shipment.freight_terms, shipment.shipment_type]
          expect(row[12].to_date).to eq order.first_expected_delivery_date.to_date
          expect(row[13].to_date).to eq shipment.booking_received_date.to_date
          expect(row[14].to_date).to eq shipment.cargo_on_hand_date.to_date
          expect(row[15].to_date).to eq shipment.docs_received_date.to_date
        end

        expect(sheet[10]).to eq [nil, nil, nil, "Totals:", 60, 300, 15, 2499.99, 60]
      end
    end
  end
end