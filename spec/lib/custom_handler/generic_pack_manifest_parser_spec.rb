require 'spec_helper'
require Rails.root.join('spec/fixtures/files/standard_booking_form')

describe OpenChain::CustomHandler::GenericPackManifestParser do

  describe 'with real data' do

  let!(:shipment) { FactoryGirl.create(:shipment, importer_id:1) }
  let!(:first_order) { FactoryGirl.create :order, customer_order_number: 1502377, importer_id:1 }
  let!(:second_order) { FactoryGirl.create :order, customer_order_number: 1502396, importer_id:1 }
  let!(:order_lines) { [FactoryGirl.create(:order_line, order_id: first_order.id, sku: 32248678), FactoryGirl.create(:order_line, order_id: first_order.id, sku: 32248654), FactoryGirl.create(:order_line, order_id: second_order.id, sku: 32248838)]}
  let!(:user) { FactoryGirl.create(:master_user, shipment_edit: true, shipment_view: true) }
  let!(:nantong_port) { FactoryGirl.create(:port, name: "Nantong") }
  let!(:shanghai_port) { FactoryGirl.create(:port, name: "Shanghai") }
  let!(:la_port) { FactoryGirl.create(:port, name:"LOS ANGELES, CA") }

  before do
    # These results are based on the standard_booking_form fixture.
    # If that changes these tests will need to change!
  end

    it 'parses it correctly' do
      result = described_class.new.run shipment, FORM_ARRAY, user
      expect(result).to be_present

      expect(shipment.receipt_location).to be_present
      expect(shipment.destination_port).to be_present
      expect(shipment.freight_terms).to be_present
      expect(shipment.lcl).not_to be_nil #false is allowed
      expect(shipment.shipment_type).to be_present
      expect(shipment.cargo_ready_date).to be_present
      expect(shipment.booking_shipment_type).to be_present
      expect(shipment.first_port_receipt).to be_present
      expect(shipment.lading_port).to be_present
      expect(shipment.unlading_port).to be_present

      expect(shipment.receipt_location).to eq "Nantong"
      expect(shipment.freight_terms).to eq "Prepaid"
      expect(shipment.lcl).to be true
      expect(shipment.shipment_type).to eq "CFS/CFS"
      expect(shipment.cargo_ready_date).to eq Date.parse("2015-05-25 00:00:00 -0400")
      expect(shipment.booking_shipment_type).to eq "CFS/CFS"
      expect(shipment.first_port_receipt).to eq nantong_port
      expect(shipment.lading_port).to eq shanghai_port
      expect(shipment.unlading_port).to eq la_port
      expect(shipment.destination_port).to eq la_port

      expect(shipment.booking_lines.length).to eq 3
      shipment.booking_lines.each do |line|
        expect(line).to be_persisted
        expect(line.shipment).to eq shipment
        expect(line.order).to be_present
        expect(line.order_line).to be_present
        expect(line.order).to be_present
        expect(line.gross_kgs).to be_present
        expect(line.cbms).to be_present
        expect(line.carton_qty).to be_present
        expect(line.product).to be_present
        expect(line.quantity).to be_present
      end

      line = shipment.booking_lines.first.reload
      expect(line.order.customer_order_number).to eq '1502377'
      expect(line.order_line.sku).to eq '32248678'
      expect(line.carton_qty).to eq 200
      expect(line.quantity).to eq 5000
      expect(line.cbms).to be_within(0.01).of 5.322
      expect(line.gross_kgs).to be_within(0.01).of 2142.200

      line = shipment.booking_lines[1].reload
      expect(line.order.customer_order_number).to eq '1502377'
      expect(line.order_line.sku).to eq '32248654'
      expect(line.carton_qty).to eq 145
      expect(line.quantity).to eq 3202
      expect(line.cbms).to be_within(0.01).of 3.456
      expect(line.gross_kgs).to be_within(0.01).of 1739.400

      line = shipment.booking_lines[2].reload
      expect(line.order.customer_order_number).to eq '1502396'
      expect(line.order_line.sku).to eq '32248838'
      expect(line.carton_qty).to eq 198
      expect(line.quantity).to eq 4676
      expect(line.cbms).to be_within(0.01).of 15.450
      expect(line.gross_kgs).to be_within(0.01).of 1920.000
    end
  end
end
