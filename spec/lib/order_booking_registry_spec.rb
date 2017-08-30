require 'spec_helper'

describe OpenChain::OrderBookingRegistry do
  before :each do
    described_class.clear
  end
  describe '#register' do
    context 'can_book?' do
      it "should register if implments can_book?, can_request_booking? and can_revise_booking?" do
        c = Class.new do
          def self.can_book?(ord, user); true; end
          def self.can_request_booking?(ord, user); true; end
          def self.can_revise_booking?(ord, user); true; end
          def self.can_edit_booking?(ord, user); true; end
        end

        described_class.register c
        expect(described_class.registered.to_a).to eq [c]
      end

      it "should fail if doesn't implement can_book?" do
        c = Class.new do
          def self.can_request_booking?(ord, user); true; end
          def self.can_revise_booking?(ord, user); true; end
          def self.can_edit_booking?(ord, user); true; end
        end

        expect{described_class.register c}.to raise_error(/can_book/)
        expect(described_class.registered.to_a).to be_empty
      end

      it "should fail if doesn't implement can_request_booking?" do
        c = Class.new do
          def self.can_book?(ord, user); true; end
          def self.can_revise_booking?(ord, user); true; end
          def self.can_edit_booking?(ord, user); true; end
        end

        expect{described_class.register c}.to raise_error(/can_request_book/)
        expect(described_class.registered.to_a).to be_empty
      end

      it "should fail if doesn't implement can_revise_booking?" do
        c = Class.new do
          def self.can_book?(ord, user); true; end
          def self.can_request_booking?(ord, user); true; end
          def self.can_edit_booking?(ord, user); true; end
        end

        expect{described_class.register c}.to raise_error(/can_revise_book/)
        expect(described_class.registered.to_a).to be_empty
      end

      it "should fail if doesn't implement can_edit_booking?" do
        c = Class.new do
          def self.can_book?(ord, user); true; end
          def self.can_request_booking?(ord, user); true; end
          def self.can_revise_booking?(ord, user); true; end
        end

        expect{described_class.register c}.to raise_error(/can_edit_book/)
        expect(described_class.registered.to_a).to be_empty
      end
    end
    context 'stubbed methods' do
      let :base_class do
        Class.new do
          def self.can_book?(ord, user); true; end
          def self.can_request_booking?(ord, user); true; end
          def self.can_revise_booking?(ord, user); true; end
          def self.can_edit_booking?(shp, user); true; end
        end
      end
      it "should stub book_from_order_hook if not implemented" do
        c = base_class
        described_class.register c
        expect{c.book_from_order_hook(double('shiphash'),double('order'),double('bookinglines'))}.to_not raise_error
        expect{c.request_booking_hook(double('shipment'),double('user'))}.to_not raise_error
        expect{c.revise_booking_hook(double('shipment'),double('user'))}.to_not raise_error
        expect{c.post_request_cancel_hook(double('shipment'),double('user'))}.to_not raise_error
        expect{c.open_bookings_hook(double('shipment_query'),double('user'), double("order"))}.to_not raise_error
      end
      it "should leave method alone if implemented" do
        c = base_class
        def c.book_from_order_hook ship_hash, order, booking_lines; order.do_something; end
        def c.request_booking_hook shipment, user; shipment.do_request_booking; end
        def c.revise_booking_hook shipment, user; shipment.do_revise_booking; end
        def c.post_request_cancel_hook shipment, user; shipment.do_request_cancel; end
        def c.open_bookings_hook(shipment, user, order); shipment.open_bookings_hook; end
        order = double('order')
        expect(order).to receive(:do_something)
        shipment = double('shipment')
        [:do_request_booking,:do_revise_booking,:do_request_cancel,:open_bookings_hook].each do |m|
          expect(shipment).to receive(m)
        end
        described_class.register c
        c.book_from_order_hook(double('ship_hash'),order,double('booking_lines'))
        c.request_booking_hook(shipment,double('user'))
        c.revise_booking_hook(shipment,double('user'))
        c.post_request_cancel_hook(shipment,double('user'))
        c.open_bookings_hook(shipment, double('user'), order)
      end
    end
  end
end
