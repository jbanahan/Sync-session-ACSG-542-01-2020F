require 'spec_helper'
require Rails.root.join('spec/fixtures/files/standard_booking_form')

describe OpenChain::CustomHandler::GenericPackManifestParser do

  let!(:shipment) { FactoryGirl.create(:shipment, importer_id:1) }
  let!(:first_order) { FactoryGirl.create :order, customer_order_number: 1502377, importer_id:1 }
  let!(:second_order) { FactoryGirl.create :order, customer_order_number: 1502396, importer_id:1 }
  let!(:order_lines) { [FactoryGirl.create(:order_line, order_id: first_order.id, sku: 32248678), FactoryGirl.create(:order_line, order_id: first_order.id, sku: 32248654), FactoryGirl.create(:order_line, order_id: second_order.id, sku: 32248838)]}
  let!(:user) { FactoryGirl.create(:master_user, shipment_edit: true, shipment_view: true) }

  before do
    # @user = double :user
    # @user.stub(:view_shipments?).and_return true
    # @user.stub(:edit_shipments?).and_return true
  end

  it 'parses it' do
    result = described_class.new.process_rows shipment, FORM_ARRAY, user
    expect(result).to be_present
    expect(shipment.booking_lines.length).to eq 3
    shipment.booking_lines.each do |line|
      expect(line.shipment).to eq shipment
      expect(line.order).to be_present
      expect(line.order_line).to be_present
      expect(line.order).to be_present
      expect(line.gross_kgs).to be_present
      expect(line.cbms).to be_present
      expect(line.carton_qty).to be_present
      expect(line.carton_set).to be_present
      expect(line.product).to be_present
      expect(line.quantity).to be_present
    end

    line = shipment.booking_lines.first
    expect(line.order.customer_order_number).to eq '1502377'
    expect(line.order_line.sku).to eq '32248678'
    expect(line.carton_qty).to eq 200
    expect(line.quantity).to eq 5000
    expect(line.cbms).to eq 5.322
    expect(line.gross_kgs).to eq 2142.200

    line = shipment.booking_lines[1]
    expect(line.order.customer_order_number).to eq '1502377'
    expect(line.order_line.sku).to eq '32248654'
    expect(line.carton_qty).to eq 145
    expect(line.quantity).to eq 3202
    expect(line.cbms).to eq 3.456
    expect(line.gross_kgs).to eq 1739.400

    line = shipment.booking_lines[2]
    expect(line.order.customer_order_number).to eq '1502396'
    expect(line.order_line.sku).to eq '32248838'
    expect(line.carton_qty).to eq 198
    expect(line.quantity).to eq 4676
    expect(line.cbms).to eq 11.819808
    expect(line.gross_kgs).to eq 1920.000
  end
end
