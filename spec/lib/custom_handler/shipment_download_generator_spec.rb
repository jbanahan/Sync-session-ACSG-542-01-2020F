require 'spec_helper'

describe OpenChain::CustomHandler::ShipmentDownloadGenerator do
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
    @shipment.stub(:can_view?).and_return true
  end

  it "runs without exploding" do
    expect(described_class.new.generate(@shipment, @user)).to be_a Spreadsheet::Workbook
  end

  describe 'with no containers' do
    it 'only has one sheet with header information' do
      workbook = subject.generate(@shipment, @user)

      expect(workbook.worksheets.count).to eq 1
      sheet = workbook.worksheet 0
      expect(sheet.row(0).to_a).to eq ["Freight Receipt Location", "Destination Port Name", "Final Destination Name", "Master Bill of Lading", "House Bill of Lading", "Vessel", "Voyage"]
      expect(sheet.row(1).to_a).to eq [@shipment.receipt_location, @shipment.destination_port.name, @shipment.final_dest_port.name, @shipment.master_bill_of_lading, @shipment.house_bill_of_lading, @shipment.vessel, @shipment.voyage]
      expect(sheet.row(2).to_a).to eq ["Confirmed On Board Origin Date", "Departure Date", "ETA Last Foreign Port Date", "Departure Last Foreign Port Date", "Est Arrival Date"]
      expect(sheet.row(3).to_a).to eq [@shipment.confirmed_on_board_origin_date, @shipment.departure_date, @shipment.eta_last_foreign_port_date, @shipment.departure_last_foreign_port_date, @shipment.est_arrival_port_date]
    end
  end

  describe 'with containers' do
    before do
      @container1 = Factory :container, shipment: @shipment, container_number: '99000', seal_number: 'SEAL1212', container_size: 'GINORMOUS'
      container2 = Factory :container, shipment: @shipment
      @order = Factory(:order, customer_order_number:'123456789', ship_window_end: 2.days.ago, first_expected_delivery_date: 1.month.from_now)

      product = Factory(:product)
      cdefs = subject.class.prep_custom_definitions [:prod_part_number]
      product.update_custom_value!(cdefs[:prod_part_number], "Part")

      3.times do
        line = Factory(:shipment_line, shipment:@shipment, product:product, container:@container1, carton_qty:rand(20), quantity:rand(100), cbms:rand(5.0), manufacturer_address:Factory(:full_address))
        order_line = Factory(:order_line, order:@order, quantity:line.quantity, product:product, country_of_origin:'GN')
        PieceSet.create(order_line:order_line, quantity:line.quantity, shipment_line:line)
      end
    end

    it 'creates a sheet for each container' do
      workbook = subject.generate(@shipment, @user)
      expect(workbook.worksheets.count).to eq 2

      sheet = workbook.worksheet(0)

      expect(sheet.rows[0].to_a).to eq ["Freight Receipt Location", "Destination Port Name", "Final Destination Name", "Master Bill of Lading", "House Bill of Lading", "Vessel", "Voyage", "Container Number", "Container Size", "Seal Number"]
      expect(sheet.rows[1].to_a).to eq [@shipment.receipt_location, @shipment.destination_port.name, @shipment.final_dest_port.name, @shipment.master_bill_of_lading, @shipment.house_bill_of_lading, @shipment.vessel, @shipment.voyage, @container1.container_number, @container1.container_size, @container1.seal_number]
      expect(sheet.rows[2].to_a).to eq ["Confirmed On Board Origin Date", "Departure Date", "ETA Last Foreign Port Date", "Departure Last Foreign Port Date", "Est Arrival Date"]
      expect(sheet.rows[3].to_a).to eq [@shipment.confirmed_on_board_origin_date, @shipment.departure_date, @shipment.eta_last_foreign_port_date, @shipment.departure_last_foreign_port_date, @shipment.est_arrival_port_date]

      expect(sheet.row(6).to_a).to eq ["Container Number", "Customer Order Number", "Part Number", "Manufacturer Address Name", "Cartons", "Quantity Shipped", "Volume (CBMS)", "Ship Window End Date", "Freight Terms", "Shipment Type", "First Expected Delivery Date", "Booking Received Date", "Cargo On Hand Date", "Docs Received Date"]
      @shipment.shipment_lines.each_with_index do |line, idx|
        row = sheet.row(7 + idx).to_a
        expect(row.first(7)).to eq [@container1.container_number, @order.customer_order_number, "Part", "MYaddr", line.carton_qty, line.quantity, line.cbms]
        expect(row[7].to_date).to eq @order.ship_window_end.to_date
        expect(row[8..9]).to eq [@shipment.freight_terms, @shipment.shipment_type]
        expect(row[10].to_date).to eq @order.first_expected_delivery_date.to_date
        expect(row[11].to_date).to eq @shipment.booking_received_date.to_date
        expect(row[12].to_date).to eq @shipment.cargo_on_hand_date.to_date
        expect(row[13].to_date).to eq @shipment.docs_received_date.to_date
      end
    end
  end
end