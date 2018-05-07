require 'spec_helper'

describe OpenChain::CustomHandler::JJill::JJillShipmentDownloadGenerator do
  before do
    @shipment = Factory :shipment,
                        receipt_location: 'Prague, CZK',
                        destination_port: Factory(:port),
                        final_dest_port: Factory(:port),
                        master_bill_of_lading: 'MASTER',
                        house_bill_of_lading: 'HOUSE',
                        vessel: 'La Fromage Du Mer',
                        voyage: '20000 Leagues',
                        booking_received_date: 1.week.ago,
                        cargo_on_hand_date: 3.days.ago,
                        docs_received_date: 2.days.ago,
                        confirmed_on_board_origin_date: 1.day.ago,
                        departure_date: 10.days.ago,
                        eta_last_foreign_port_date: 9.days.ago,
                        departure_last_foreign_port_date: 8.days.ago,
                        est_arrival_port_date: 7.days.ago,
                        freight_terms: "FOB",
                        shipment_type: "TYPE"


    @user = Factory :master_user
    allow(@shipment).to receive(:can_view?).and_return true
  end

  def create_all_data
     @container1 = Factory :container, shipment: @shipment, container_number: '99000', seal_number: 'SEAL1212', container_size: 'GINORMOUS'
     @container2 = Factory :container, shipment: @shipment, container_number: '99099', seal_number: 'SEAL2020', container_size: 'MODEST'
     @order = Factory(:order, customer_order_number:'123456789', ship_window_end: Date.new(2016,03,15), first_expected_delivery_date: Date.new(2016,03,20))
     @order2 = Factory(:order, customer_order_number:'987654321', ship_window_end: Date.new(2016,03,16), first_expected_delivery_date: Date.new(2016,03,21))
     co = Factory(:country, iso_code: "US")
     @addr = Factory(:address, name: "123 St", country: co)
     addr2 = Factory(:address, name: "456 St", country: co)
     create_lines @shipment, @order, [{carton_qty: 5, quantity: 10, cbms: 15, manufacturer_address: @addr, container: @container1},
                                      {carton_qty: 6, quantity: 11, cbms: 16, manufacturer_address: addr2, container: @container1}]
     create_lines @shipment, @order2, [{carton_qty: 4, quantity: 9, cbms: 14, manufacturer_address: @addr, container: @container1}]
  end

  def create_lines shipment, order, line_params
    product = Factory(:product, importer: Factory(:importer))
    @cdefs ||= subject.class.prep_custom_definitions([:prod_part_number])
    product.update_custom_value!(@cdefs[:prod_part_number], "Part")

    line_params.each do |p|
      line = Factory(:shipment_line, shipment:shipment, product:product, container: p[:container], carton_qty: p[:carton_qty], quantity: p[:quantity], cbms: p[:cbms], manufacturer_address:p[:manufacturer_address])
      order_line = Factory(:order_line, order:order, quantity:line.quantity, product:product, country_of_origin:'GN')
      PieceSet.create(order_line:order_line, quantity:line.quantity, shipment_line:line)
    end
    @shipment.reload
  end

  describe "generate" do
    it "runs without exploding" do
      expect(described_class.new.generate(@shipment, @user)).to be_a Spreadsheet::Workbook
    end

    context "with no containers" do
      it 'only has one sheet with header information for ocean shipments' do
        workbook = subject.generate(@shipment, @user)

        expect(workbook.worksheets.count).to eq 1
        sheet = workbook.worksheet 0
        expect(sheet.row(0).to_a).to eq ["Freight Receipt Location", "Discharge Port Name", "Final Destination Name", "Master Bill of Lading", "House Bill of Lading", "Vessel", "Voyage"]
        expect(sheet.row(1).to_a).to eq [@shipment.receipt_location, @shipment.destination_port.name, @shipment.final_dest_port.name, @shipment.master_bill_of_lading, @shipment.house_bill_of_lading, @shipment.vessel, @shipment.voyage]
        expect(sheet.row(2).to_a).to eq ["Confirmed On Board Origin Date", "Departure Date", "ETA Last Origin Port Date", "Departure Last Origin Port Date", "Est Arrival Discharge"]
        expect(sheet.row(3).to_a).to eq [@shipment.confirmed_on_board_origin_date, @shipment.departure_date, @shipment.eta_last_foreign_port_date, @shipment.departure_last_foreign_port_date, @shipment.est_arrival_port_date]
      end

      it 'rolls up' do
        create_all_data
        ShipmentLine.all.each{ |sl| sl.update_attributes! container_id: nil, shipment_id: @shipment.id }
        Container.destroy_all
        workbook = subject.generate(@shipment, @user)

        sheet = workbook.worksheet 0
        row = sheet.row(7)

        expect(row[0..6]).to eq ["", @order.customer_order_number, "Part", "123 St, 456 St", 11, 21, 31]
        expect(row[7].to_date).to eq @order.ship_window_end.to_date
        expect(row[8..9]).to eq [@shipment.freight_terms, @shipment.shipment_type]
        expect(row[10].to_date).to eq @order.first_expected_delivery_date.to_date
        expect(row[11].to_date).to eq @shipment.booking_received_date.to_date
        expect(row[12].to_date).to eq @shipment.cargo_on_hand_date.to_date
        expect(row[13].to_date).to eq @shipment.docs_received_date.to_date

        row = sheet.row(8).to_a
        expect(row[0..6]).to eq ["", @order2.customer_order_number, "Part", "123 St", 4, 9, 14]
        expect(row[7].to_date).to eq @order2.ship_window_end.to_date
        expect(row[8..9]).to eq [@shipment.freight_terms, @shipment.shipment_type]
        expect(row[10].to_date).to eq @order2.first_expected_delivery_date.to_date
        expect(row[11].to_date).to eq @shipment.booking_received_date.to_date
        expect(row[12].to_date).to eq @shipment.cargo_on_hand_date.to_date
        expect(row[13].to_date).to eq @shipment.docs_received_date.to_date
      end

      it "includes line details for air shipments" do
        @shipment.mode = 'Air'
        @order = Factory(:order, customer_order_number:'123456789', ship_window_end: 2.days.ago, first_expected_delivery_date: 1.month.from_now)
        create_lines @shipment, @order, [{carton_qty: 5, quantity: 10, cbms: 15, manufacturer_address: Factory(:full_address)}]

        workbook = subject.generate(@shipment, @user)
        sheet = workbook.worksheet(0)
        expect(sheet.rows[1].to_a).to eq [@shipment.receipt_location, @shipment.destination_port.name, @shipment.final_dest_port.name, @shipment.master_bill_of_lading, @shipment.house_bill_of_lading, @shipment.vessel, @shipment.voyage]
        expect(sheet.rows[3].to_a).to eq [@shipment.confirmed_on_board_origin_date, @shipment.departure_date, @shipment.eta_last_foreign_port_date, @shipment.departure_last_foreign_port_date, @shipment.est_arrival_port_date]

        line = @shipment.shipment_lines.first

        row = sheet.row(7).to_a
        expect(row.first(7)).to eq ["", @order.customer_order_number, "Part", "MYaddr", line.carton_qty, line.quantity, line.cbms]
        expect(row[7].to_date).to eq @order.ship_window_end.to_date
        expect(row[8..9]).to eq [@shipment.freight_terms, @shipment.shipment_type]
        expect(row[10].to_date).to eq @order.first_expected_delivery_date.to_date
        expect(row[11].to_date).to eq @shipment.booking_received_date.to_date
        expect(row[12].to_date).to eq @shipment.cargo_on_hand_date.to_date
        expect(row[13].to_date).to eq @shipment.docs_received_date.to_date
      end

      it "falls back to unique identifier for part number if no part number field is present" do
        @order = Factory(:order, customer_order_number:'123456789', ship_window_end: 2.days.ago, first_expected_delivery_date: 1.month.from_now)
        create_lines @shipment, @order, [{carton_qty: 5, quantity: 10, cbms: 15, manufacturer_address: Factory(:full_address)}]
        prod = @shipment.shipment_lines.first.order_lines.first.product
        prod.update_custom_value!(@cdefs[:prod_part_number], "")

        prod.update_attributes! unique_identifier: "SYSCODE-Part123"
        # The process strips the importer system code from the product's unique identifier too, so set that up
        prod.importer.update_attributes! system_code: "SYSCODE"

        workbook = subject.generate(@shipment, @user)
        sheet = workbook.worksheet(0)
        line = @shipment.shipment_lines.first
        expect(sheet.row(7).to_a[2]).to eq "Part123"
      end

      it "falls back to unique identifier for part number if no part number field is present without stripping system code" do
        # If the part unique id doesn't start with the importer's syscode, then don't bother stripping anything.
        @order = Factory(:order, customer_order_number:'123456789', ship_window_end: 2.days.ago, first_expected_delivery_date: 1.month.from_now)
        create_lines @shipment, @order, [{carton_qty: 5, quantity: 10, cbms: 15, manufacturer_address: Factory(:full_address)}]
        prod = @shipment.shipment_lines.first.order_lines.first.product
        prod.update_custom_value!(@cdefs[:prod_part_number], "")

        prod.update_attributes! unique_identifier: "ABC-Part123"
        # The process strips the importer system code from the product's unique identifier too, so set that up
        prod.importer.update_attributes! system_code: "SYSCODE"

        workbook = subject.generate(@shipment, @user)
        sheet = workbook.worksheet(0)
        line = @shipment.shipment_lines.first
        expect(sheet.row(7).to_a[2]).to eq "ABC-Part123"
      end
    end

    context "with containers" do
      before do 
        @shipment.update_attributes! mode: "Ocean"
        create_all_data 
      end

      it 'creates a sheet for each container' do
        create_lines @shipment, @order2, [{carton_qty: 4, quantity: 9, cbms: 14, manufacturer_address: @addr, container: @container2}]
        workbook = subject.generate(@shipment, @user)
        expect(workbook.worksheets.count).to eq 2

        #CONTAINER 1
        sheet = workbook.worksheet(0)

        expect(sheet.rows[0].to_a).to eq ["Freight Receipt Location", "Discharge Port Name", "Final Destination Name", "Master Bill of Lading", "House Bill of Lading", "Vessel", "Voyage", "Container Number", "Container Size", "Seal Number"]
        expect(sheet.rows[1].to_a).to eq [@shipment.receipt_location, @shipment.destination_port.name, @shipment.final_dest_port.name, @shipment.master_bill_of_lading, @shipment.house_bill_of_lading, @shipment.vessel, @shipment.voyage, @container1.container_number, @container1.container_size, @container1.seal_number]
        expect(sheet.rows[2].to_a).to eq ["Confirmed On Board Origin Date", "Departure Date", "ETA Last Origin Port Date", "Departure Last Origin Port Date", "Est Arrival Discharge"]
        expect(sheet.rows[3].to_a).to eq [@shipment.confirmed_on_board_origin_date, @shipment.departure_date, @shipment.eta_last_foreign_port_date, @shipment.departure_last_foreign_port_date, @shipment.est_arrival_port_date]

        expect(sheet.row(6).to_a).to eq ["Container Number", "Customer Order Number", "Part Number", "Manufacturer (Name)", "Cartons", "Quantity Shipped", "Volume (CBMS)", "Ship Window End Date", "Freight Terms", "Shipment Type", "First Expected Delivery Date", "Booking Received Date", "Cargo On Hand Date", "Docs Received Date", "Fish & Wildlife Flag", "Warehouse Code"]
        
        #SHOWS ROLL-UP
        row = sheet.row(7).to_a
        expect(row[0..6]).to eq ["99000", @order.customer_order_number, "Part", "123 St, 456 St", 11, 21, 31]
        expect(row[7].to_date).to eq @order.ship_window_end.to_date
        expect(row[8..9]).to eq [@shipment.freight_terms, @shipment.shipment_type]
        expect(row[10].to_date).to eq @order.first_expected_delivery_date.to_date
        expect(row[11].to_date).to eq @shipment.booking_received_date.to_date
        expect(row[12].to_date).to eq @shipment.cargo_on_hand_date.to_date
        expect(row[13].to_date).to eq @shipment.docs_received_date.to_date

        row = sheet.row(8).to_a
        expect(row[0..6]).to eq ["99000", @order2.customer_order_number, "Part", "123 St", 4, 9, 14]
        expect(row[7].to_date).to eq @order2.ship_window_end.to_date
        expect(row[8..9]).to eq [@shipment.freight_terms, @shipment.shipment_type]
        expect(row[10].to_date).to eq @order2.first_expected_delivery_date.to_date
        expect(row[11].to_date).to eq @shipment.booking_received_date.to_date
        expect(row[12].to_date).to eq @shipment.cargo_on_hand_date.to_date
        expect(row[13].to_date).to eq @shipment.docs_received_date.to_date

        #CONTAINER 2
        sheet = workbook.worksheet(1)

        expect(sheet.rows[0].to_a).to eq ["Freight Receipt Location", "Discharge Port Name", "Final Destination Name", "Master Bill of Lading", "House Bill of Lading", "Vessel", "Voyage", "Container Number", "Container Size", "Seal Number"]
        expect(sheet.rows[1].to_a).to eq [@shipment.receipt_location, @shipment.destination_port.name, @shipment.final_dest_port.name, @shipment.master_bill_of_lading, @shipment.house_bill_of_lading, @shipment.vessel, @shipment.voyage, @container2.container_number, @container2.container_size, @container2.seal_number]
        expect(sheet.rows[2].to_a).to eq ["Confirmed On Board Origin Date", "Departure Date", "ETA Last Origin Port Date", "Departure Last Origin Port Date", "Est Arrival Discharge"]
        expect(sheet.rows[3].to_a).to eq [@shipment.confirmed_on_board_origin_date, @shipment.departure_date, @shipment.eta_last_foreign_port_date, @shipment.departure_last_foreign_port_date, @shipment.est_arrival_port_date]

        expect(sheet.row(6).to_a).to eq ["Container Number", "Customer Order Number", "Part Number", "Manufacturer (Name)", "Cartons", "Quantity Shipped", "Volume (CBMS)", "Ship Window End Date", "Freight Terms", "Shipment Type", "First Expected Delivery Date", "Booking Received Date", "Cargo On Hand Date", "Docs Received Date", "Fish & Wildlife Flag", "Warehouse Code"]

        row = sheet.row(7).to_a
        expect(row[0..6]).to eq ["99099", @order2.customer_order_number, "Part", "123 St", 4, 9, 14]
        expect(row[7].to_date).to eq @order2.ship_window_end.to_date
        expect(row[8..9]).to eq [@shipment.freight_terms, @shipment.shipment_type]
        expect(row[10].to_date).to eq @order2.first_expected_delivery_date.to_date
        expect(row[11].to_date).to eq @shipment.booking_received_date.to_date
        expect(row[12].to_date).to eq @shipment.cargo_on_hand_date.to_date
        expect(row[13].to_date).to eq @shipment.docs_received_date.to_date
      end
    end
  end
end