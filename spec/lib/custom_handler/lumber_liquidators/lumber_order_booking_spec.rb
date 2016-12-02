require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberOrderBooking do
  describe 'registry' do
    it "should be able to be registered" do
      expect{OpenChain::OrderBookingRegistry.register(described_class)}.to_not raise_error
    end
  end
  describe '#can_book?' do
    let :vendor do
      c = Company.new
      c.id = 99
      c
    end
    let :user do
      u = User.new
      u.company = vendor
      allow(u).to receive(:edit_shipments?).and_return true
      u
    end
    let :order do
      o = Order.new
      allow(o).to receive(:booking_lines_by_order_line).and_return []
      allow(o).to receive(:business_rules_state).and_return 'Pass'
      o.vendor = vendor
      o
    end
    it "should return true if all conditions are met" do
      expect(described_class.can_book?(order,user)).to be_truthy
    end
    it "should return false if order is already on a booking" do
      o = order
      expect(o).to receive(:booking_lines_by_order_line).and_return ['x']
      expect(described_class.can_book?(o,user)).to be_falsey
    end
    it "should return false if user cannot edit shipments" do
      u = user
      expect(u).to receive(:edit_shipments?).and_return false
      expect(described_class.can_book?(order,u)).to be_falsey
    end
    it "should return false if user's company is not order's vendor" do
      c2 = Company.new
      c2.id = 100
      o = order
      o.vendor = c2
      expect(described_class.can_book?(o,user)).to be_falsey
    end
    it "should return false if order has failed business rules" do
      o = order
      expect(o).to receive(:business_rules_state).and_return 'Fail'
      expect(described_class.can_book?(o,user)).to be_falsey
    end
    it "should return false if business rules have not been run" do
      o = order
      expect(o).to receive(:business_rules_state).and_return nil
      expect(described_class.can_book?(o,user)).to be_falsey
    end
  end

  describe '#book_from_order_hook' do
    it "should set defaults" do
      expected = {
        shp_fwd_syscode:'dhl',
        shp_booking_mode:'Ocean',
        shp_booking_shipment_type:'CY'
      }
      o = double(:order)
      sh = {}
      booking_lines = double(:booking_lines)
      described_class.book_from_order_hook(sh,o,booking_lines)
      expected.each {|k,v| expect(sh[k]).to eq v}
    end
  end

  describe '#request_booking_hook' do
    it "should copy shipment fields to booking" do
      s = Shipment.new(
        shipment_type:'CY',
        mode:'Ocean',
        first_port_receipt_id:199,
        requested_equipment:'4 40HC',
        cargo_ready_date:Date.new(2015,1,1)
      )
      u = double('user')
      described_class.request_booking_hook s, u
      expect(s.booking_shipment_type).to eq s.shipment_type
      expect(s.booking_mode).to eq s.mode
      expect(s.booking_first_port_receipt_id).to eq s.first_port_receipt_id
      expect(s.booking_requested_equipment).to eq s.requested_equipment
      expect(s.booking_cargo_ready_date).to eq s.cargo_ready_date
    end
  end

  describe '#revise_booking_hook' do
    it "should copy shipment fields to booking" do
      s = Shipment.new(
        shipment_type:'CY',
        mode:'Ocean',
        first_port_receipt_id:199,
        requested_equipment:'4 40HC',
        cargo_ready_date:Date.new(2015,1,1)
      )
      u = double('user')
      described_class.revise_booking_hook s, u
      expect(s.booking_shipment_type).to eq s.shipment_type
      expect(s.booking_mode).to eq s.mode
      expect(s.booking_first_port_receipt_id).to eq s.first_port_receipt_id
      expect(s.booking_requested_equipment).to eq s.requested_equipment
      expect(s.booking_cargo_ready_date).to eq s.cargo_ready_date
    end
  end

  describe '#can_revise_booking_hook' do
    it "should allow if user can edit and is vendor" do
      s = Shipment.new
      v = Company.new
      u = User.new
      u.company = v
      s.vendor = v
      expect(s).to receive(:can_edit?).with(u).and_return true
      expect(described_class.can_revise_booking_hook(s,u)).to be_truthy
    end
    it "should not allow if user is not vendor" do
      s = Shipment.new
      v = Company.new
      s.vendor = v
      u = User.new
      u.company = Company.new
      allow(s).to receive(:can_edit?).with(u).and_return true
      expect(described_class.can_revise_booking_hook(s,u)).to be_falsey
    end
    it "should not allow if user cannot edit" do
      s = Shipment.new
      v = Company.new
      u = User.new
      u.company = v
      s.vendor = v
      expect(s).to receive(:can_edit?).with(u).and_return false
      expect(described_class.can_revise_booking_hook(s,u)).to be_falsey
    end
    it "should not allow if shipment is canceled" do
      s = Shipment.new(canceled_date:Time.now)
      v = Company.new
      u = User.new
      u.company = v
      s.vendor = v
      allow(s).to receive(:can_edit?).with(u).and_return true
      expect(described_class.can_revise_booking_hook(s,u)).to be_falsey
    end
  end

  describe '#post_request_cancel_hook' do
    it 'should automatically cancel' do
      s = Shipment.new
      user = User.new
      expect(s).to receive(:cancel_shipment!).with(user)
      described_class.post_request_cancel_hook(s,user)
    end
  end
end
