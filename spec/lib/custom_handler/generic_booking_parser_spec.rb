require 'spec_helper'
require Rails.root.join('spec/fixtures/files/standard_booking_form')

describe OpenChain::CustomHandler::GenericBookingParser do

  describe 'with valid data' do

  let!(:importer) { FactoryGirl.create :company, importer:true, system_code:'SYSTEM'}
  let!(:product) { FactoryGirl.create :product, unique_identifier:"#{importer.system_code}-WPT028533"}
  let!(:shipment) { FactoryGirl.create(:shipment, importer_id:importer.id) }
  let!(:first_order) { FactoryGirl.create :order, customer_order_number: 1502377, importer_id:importer.id }
  let!(:second_order) { FactoryGirl.create :order, customer_order_number: 1502396, importer_id:importer.id }
  let!(:third_order) { FactoryGirl.create :order, customer_order_number: 1502397, importer_id:importer.id }
  let!(:fourth_order) { FactoryGirl.create :order, customer_order_number: 1502398, importer_id:importer.id }
  let!(:order_lines) { [FactoryGirl.create(:order_line, order_id: first_order.id, sku: 32248678), FactoryGirl.create(:order_line, order_id: first_order.id, sku: 32248654), FactoryGirl.create(:order_line, order_id: second_order.id, sku: 32248838)]}
  let!(:user) { FactoryGirl.create(:master_user, shipment_edit: true, shipment_view: true) }

  before do
    # These results are based on the standard_booking_form fixture.
    # If that changes these tests will need to change!
  end

    it 'parses it correctly' do
      result = described_class.new.process_rows shipment, FORM_ARRAY, user
      expect(result).to be_present

      expect(shipment.receipt_location).to be_present
      expect(shipment.freight_terms).to be_present
      expect(shipment.lcl).not_to be_nil #false is allowed
      expect(shipment.shipment_type).to be_present
      expect(shipment.cargo_ready_date).to be_present
      expect(shipment.booking_shipment_type).to be_present
      expect(shipment.mode).to be_present
      expect(shipment.first_port_receipt).to be_nil
      expect(shipment.lading_port).to be_nil
      expect(shipment.unlading_port).to be_nil
      expect(shipment.destination_port).to be_nil

      expect(shipment.receipt_location).to eq "Sheerness, United Kingdom"
      expect(shipment.freight_terms).to eq  "Collect"
      expect(shipment.mode).to eq "Air"
      expect(shipment.lcl).to be false
      expect(shipment.shipment_type).to eq "CFS/CY"
      expect(shipment.cargo_ready_date).to eq Date.parse("2015-05-25 00:00:00 -0400")
      expect(shipment.booking_shipment_type).to eq "CFS/CY"

      expect(shipment.booking_lines.length).to eq 7
      shipment.booking_lines.each do |line|
        expect(line).to be_persisted
        expect(line.shipment).to eq shipment
        expect(line.gross_kgs).to be_present
        expect(line.cbms).to be_present
        expect(line.carton_qty).to be_present
        expect(line.quantity).to be_present
      end

      line = shipment.booking_lines.first.reload
      expect(line.customer_order_number).to eq '1502377'
      expect(line.order_line.sku).to eq '32248678'
      expect(line.carton_qty).to eq 200
      expect(line.quantity).to eq 5000
      expect(line.cbms).to be_within(0.01).of 5.322
      expect(line.gross_kgs).to be_within(0.01).of 2142.200

      line = shipment.booking_lines[1].reload
      expect(line.customer_order_number).to eq '1502377'
      expect(line.order_line.sku).to eq '32248654'
      expect(line.carton_qty).to eq 145
      expect(line.quantity).to eq 3202
      expect(line.cbms).to be_within(0.01).of 3.456
      expect(line.gross_kgs).to be_within(0.01).of 1739.400

      line = shipment.booking_lines[2].reload
      expect(line.customer_order_number).to eq '1502396'
      expect(line.order_line.sku).to eq '32248838'
      expect(line.carton_qty).to eq 198
      expect(line.quantity).to eq 4676
      expect(line.cbms).to be_within(0.01).of 15.450
      expect(line.gross_kgs).to be_within(0.01).of 1920.000

      line = shipment.booking_lines[3].reload
      expect(line.customer_order_number).to eq '1502397'
      expect(line.product_id).to eq product.id
      expect(line.order_id).to eq third_order.id
      expect(line.carton_qty).to eq 198
      expect(line.quantity).to eq 4676
      expect(line.cbms).to be_within(0.01).of 15.450
      expect(line.gross_kgs).to be_within(0.01).of 1920.000

      line = shipment.booking_lines[4].reload
      expect(line.customer_order_number).to be_nil
      expect(line.product_id).to eq product.id
      expect(line.carton_qty).to eq 198
      expect(line.quantity).to eq 4676
      expect(line.cbms).to be_within(0.01).of 15.450
      expect(line.gross_kgs).to be_within(0.01).of 1920.000

      line = shipment.booking_lines[5].reload
      expect(line.customer_order_number).to eq '1502398'
      expect(line.product_id).to be_nil
      expect(line.carton_qty).to eq 198
      expect(line.quantity).to eq 4676
      expect(line.cbms).to be_within(0.01).of 15.450
      expect(line.gross_kgs).to be_within(0.01).of 1920.000

      line = shipment.booking_lines[6].reload
      expect(line.customer_order_number).to be_nil
      expect(line.product_id).to be_nil
      expect(line.carton_qty).to eq 198
      expect(line.quantity).to eq 4676
      expect(line.cbms).to be_within(0.01).of 15.450
      expect(line.gross_kgs).to be_within(0.01).of 1920.000
    end
  end

  describe 'with invalid data' do
    describe 'when SKU is provided but not PO number' do
      let(:shipment) { FactoryGirl.build :shipment, importer_id:1 }
      it 'raises an error' do
        parser = described_class.new
        file_layout = parser.send 'file_layout'
        row_with_sku = Array.new(12)
        row_with_sku[file_layout[:sku_column]] = 'THISISANSKU'
        expect { parser.send 'add_line', shipment, row_with_sku, 1}.to raise_error
      end
    end
  end
end
