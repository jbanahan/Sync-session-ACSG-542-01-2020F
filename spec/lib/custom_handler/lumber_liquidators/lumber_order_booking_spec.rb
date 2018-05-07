require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberOrderBooking do
  subject {described_class}

  let (:booking_unlocked_date) { 
      Class.new {
        include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
        }.prep_custom_definitions([:shp_booking_unlocked_date])[:shp_booking_unlocked_date]
    }

  let (:ordln_gross_weight_kg) { 
      Class.new {
        include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
        }.prep_custom_definitions([:ordln_gross_weight_kg])[:ordln_gross_weight_kg]
    }

  describe 'registry' do
    it "should be able to be registered" do
      expect{OpenChain::Registries::OrderBookingRegistry.register(described_class)}.to_not raise_error
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
      expect(subject.can_book?(order,user)).to be_truthy
    end
    it "should return false if order is already on a booking" do
      o = order
      expect(o).to receive(:booking_lines_by_order_line).and_return ['x']
      expect(subject.can_book?(o,user)).to be_falsey
    end
    it "should return false if user cannot edit shipments" do
      u = user
      expect(u).to receive(:edit_shipments?).and_return false
      expect(subject.can_book?(order,u)).to be_falsey
    end
    it "should return false if user's company is not order's vendor" do
      c2 = Company.new
      c2.id = 100
      o = order
      o.vendor = c2
      expect(subject.can_book?(o,user)).to be_falsey
    end
    it "should return false if order has failed business rules" do
      o = order
      expect(o).to receive(:business_rules_state).and_return 'Fail'
      expect(subject.can_book?(o,user)).to be_falsey
    end
    it "should return false if business rules have not been run" do
      o = order
      expect(o).to receive(:business_rules_state).and_return nil
      expect(subject.can_book?(o,user)).to be_falsey
    end
  end

  describe 'book_from_order_hook' do
    let (:importer) {
      c = Company.create!(system_code: "Importer", name: "Importer")
      c.addresses.create! address_type: "ISF Buyer"
      c
    }
    it "sets default values" do
      ordln_gross_weight_kg

      order = Order.new
      order.importer = importer
      line = order.order_lines.build ship_to_id: 1
      line.id = 20
      line.find_and_set_custom_value ordln_gross_weight_kg, 10

      fields = {}

      booking_lines = [{bkln_order_line_id: 20}]
      subject.book_from_order_hook fields, order, booking_lines

      expect(fields[:shp_ship_to_address_id]).to eq 1
      expect(fields[:shp_fwd_syscode]).to eq "allport"
      expect(fields[:shp_booking_mode]).to eq "Ocean"
      expect(fields[:shp_booking_shipment_type]).to eq "CY"

      expect(booking_lines.first[:bkln_gross_kgs]).to eq 10
      expect(fields[:shp_consignee_id]).to eq importer.id
      expect(fields[:shp_buyer_address_id]).to eq importer.addresses.find {|a| a.address_type == "ISF Buyer"}.id
    end

    it "skips defaults if shipment already exists" do
      fields = {id: 1}

      subject.book_from_order_hook fields, Order.new, []
      expect(fields).to eq({id: 1})
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
      s.find_and_set_custom_value booking_unlocked_date, Time.zone.now
      u = double('user')
      subject.request_booking_hook s, u
      expect(s.booking_shipment_type).to eq s.shipment_type
      expect(s.booking_mode).to eq s.mode
      expect(s.booking_first_port_receipt_id).to eq s.first_port_receipt_id
      expect(s.booking_requested_equipment).to eq s.requested_equipment
      expect(s.booking_cargo_ready_date).to eq s.cargo_ready_date
      expect(s.custom_value(booking_unlocked_date)).to be_nil
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
      s.find_and_set_custom_value booking_unlocked_date, Time.zone.now

      u = double('user')
      subject.revise_booking_hook s, u
      expect(s.booking_shipment_type).to eq s.shipment_type
      expect(s.booking_mode).to eq s.mode
      expect(s.booking_first_port_receipt_id).to eq s.first_port_receipt_id
      expect(s.booking_requested_equipment).to eq s.requested_equipment
      expect(s.booking_cargo_ready_date).to eq s.cargo_ready_date
      expect(s.custom_value(booking_unlocked_date)).to be_nil
    end
  end

  describe '#can_revise_booking?' do

    let (:delivery_location) { Factory(:port, unlocode: "LOCOD") }
    let (:shipment) { 
      s = Factory(:shipment, reference: "12345", mode: "mode", shipment_type: "type", cargo_ready_date: Time.zone.now, requested_equipment: "1", first_port_receipt: delivery_location, vendor: company)
      s.attachments.create! attached_file_name: "file.pdf", attachment_type: "VDS-Vendor Document Set"
      s.booking_lines.create order: order, order_line: order.order_lines.first, quantity: 10, cbms: 10
      s
    }
    let (:user) { 
      u = User.new 
      u.company = company
      u
    }
    let (:company) { Company.new }
    let (:order) { 
      o = Factory(:order, fob_point: delivery_location.unlocode) 
      l = Factory(:order_line, order: o)
      o
    }

    before :each do 
      shipment.booking_received_date = Time.zone.now
      shipment.find_and_set_custom_value booking_unlocked_date, Time.zone.now
      allow(shipment).to receive(:can_edit?).with(user).and_return true
    end

    it "should allow if user can edit and is vendor and Booking Received is not null and Booking Unlocked Date is set" do
      expect(subject.can_revise_booking?(shipment,user)).to eq true
    end

    it "should not allow if order fob point does not match booking" do
      order.update_attributes! fob_point: "BLAHBLAH"
      expect(subject.can_revise_booking?(shipment,user)).to eq false
    end

    it "does not allow booking to be revised if there are no VDS docs" do
      shipment.attachments.destroy_all
      expect(subject.can_revise_booking?(shipment,user)).to eq false
    end

    it "does not allow booking to be revised if there are no booking lines" do
      shipment.booking_lines.destroy_all
      expect(subject.can_revise_booking?(shipment,user)).to eq false
    end

    it "does not allow booking to be revised if booking line is missing a volume" do
      shipment.booking_lines.first.update_attributes! cbms: 0
      expect(subject.can_revise_booking?(shipment,user)).to eq false
    end

    it "should not allow if user can edit and is vendor and Booking Received is not null and Booking Unlocked Date is not set" do
      shipment.find_and_set_custom_value booking_unlocked_date, nil
      expect(subject.can_revise_booking?(shipment,user)).to eq false
    end

    it "should not allow if user can edit and is vendor and Booking Received is null and Booking Unlocked Date is set" do
      shipment.booking_received_date = nil
      expect(subject.can_revise_booking?(shipment,user)).to eq false
    end

    it "should not allow if user is not vendor" do
      shipment.vendor = Company.new
      expect(subject.can_revise_booking?(shipment,user)).to eq false
    end
    it "should not allow if user cannot edit" do
      expect(shipment).to receive(:can_edit?).with(user).and_return false
      expect(subject.can_revise_booking?(shipment,user)).to eq false
    end
    it "should not allow if shipment is canceled" do
      shipment.canceled_date = Time.zone.now
      expect(subject.can_revise_booking?(shipment,user)).to eq false
    end
    it "does not allow if shipment is missing fields" do
      # The full range of fields is checked elswhere, just make sure we're chekcing them for this
      shipment.mode = ""
      expect(subject.can_revise_booking?(shipment,user)).to eq false
    end
  end

  describe "can_request_booking?" do

    let (:delivery_location) { Factory(:port, unlocode: "LOCOD") }
    let (:shipment) { 
      s = Factory(:shipment, reference: "12345", mode: "mode", shipment_type: "type", cargo_ready_date: Time.zone.now, requested_equipment: "1", first_port_receipt: delivery_location, vendor: company)
      s.attachments.create! attached_file_name: "file.pdf", attachment_type: "VDS-Vendor Document Set"
      s.booking_lines.create order: order, order_line: order.order_lines.first, quantity: 10, cbms: 10
      s
    }

    let (:user) { 
      u = User.new 
      u.company = company
      u
    }
    let (:company) { Factory(:company) }
    let (:order) { 
      o = Factory(:order, fob_point: delivery_location.unlocode) 
      l = Factory(:order_line, order: o)
      o
    }

    before :each do
      booking_unlocked_date
      allow(shipment).to receive(:can_edit?).with(user).and_return true
    end

    it "does not allow booking to be requested unless several fields have values and user is vendor and can edit shipment" do
      expect(subject.can_request_booking?(shipment, user)).to eq true
    end

    it "does not allow booking to be requested if order delivery location does not match the shipments" do
      order.update_attributes! fob_point: "BLAHBLAH"
      expect(subject.can_request_booking?(shipment,user)).to eq false
    end

    it "does not allow booking to be requested if there are no VDS docs" do
      shipment.attachments.destroy_all
      expect(subject.can_request_booking?(shipment,user)).to eq false
    end

    it "does not allow booking to be requested if there are no booking lines" do
      shipment.booking_lines.destroy_all
      expect(subject.can_request_booking?(shipment,user)).to eq false
    end

    it "does not allow booking to be requested if booking line is missing a volume" do
      shipment.booking_lines.first.update_attributes! cbms: 0
      expect(subject.can_request_booking?(shipment,user)).to eq false
    end

    it "does not allow booking to be requested if mode is blank" do
      shipment.mode = ""
      expect(subject.can_request_booking?(shipment, user)).to eq false
    end

    it "does not allow booking to be requested if shipment type is blank" do
      shipment.shipment_type = ""
      expect(subject.can_request_booking?(shipment, user)).to eq false
    end

    it "does not allow booking to be requested if requested equipment is blank" do
      shipment.requested_equipment = ""
      expect(subject.can_request_booking?(shipment, user)).to eq false
    end

    it "does not allow booking to be requested if cargo ready date is blank" do
      shipment.cargo_ready_date = nil
      expect(subject.can_request_booking?(shipment, user)).to eq false
    end

    it "does not allow booking to be requested if first port receipt is blank" do
      shipment.first_port_receipt = nil
      expect(subject.can_request_booking?(shipment, user)).to eq false
    end

    it "does not allow booking if shipment vendor is not user's company" do
      shipment.vendor = Company.new
      expect(subject.can_request_booking?(shipment, user)).to eq false
    end

    it "does not allow booking if user cannot edit shipments" do
      expect(shipment).to receive(:can_edit?).with(user).and_return false
      expect(subject.can_request_booking?(shipment, user)).to eq false
    end

    it "does not allow booking if shipment is cancelled" do
      shipment.canceled_date = Time.zone.now
      expect(subject.can_request_booking?(shipment, user)).to eq false
    end

    it "does not allow booking if booking has already been received" do
      shipment.booking_received_date = Time.zone.now
      expect(subject.can_request_booking?(shipment, user)).to eq false
    end
  end

  describe '#post_request_cancel_hook' do
    it 'should automatically cancel' do
      s = Shipment.new
      user = User.new
      expect(s).to receive(:cancel_shipment!).with(user)
      subject.post_request_cancel_hook(s,user)
    end
  end

  describe "open_bookings_hook" do
    let! (:shipment) { Factory(:shipment) }

    before :each do 
      booking_unlocked_date
    end

    it "returns bookings that do not have booking received dates" do
      shipments = subject.open_bookings_hook(nil, Shipment.scoped, nil)
      expect(shipments.all).to include shipment
    end

    it "does not return shipments that have a booking received date" do
      shipment.update_attributes! booking_received_date: Time.zone.now
      shipments = subject.open_bookings_hook(nil, Shipment.scoped, nil)
      expect(shipments.all).not_to include shipment
    end

    it "returns bookings that have a booking received date and a booking unlocked date" do
      shipment.update_custom_value! booking_unlocked_date, Time.zone.now

      shipments = subject.open_bookings_hook(nil, Shipment.scoped, nil)
      expect(shipments.all).to include shipment
    end

    it "does not return bookings that are cancelled" do
      shipment.update_attributes! canceled_date: Time.zone.now
      shipments = subject.open_bookings_hook(nil, Shipment.scoped, nil)
      expect(shipments.all).not_to include shipment
    end
  end

  describe "can_edit_booking?" do
    let (:shipment) { Shipment.new }
    let (:user) { User.new }

    it "allows editing booking if booking received date is nil" do
      expect(subject).to receive(:base_booking_permissions).with(shipment, user).and_return true
      expect(subject.can_edit_booking? shipment, user).to eq true
    end

    it "denies if booking received date is not null" do
      shipment.find_and_set_custom_value booking_unlocked_date, nil
      shipment.booking_received_date = Time.zone.now


      expect(subject).to receive(:base_booking_permissions).with(shipment, user).and_return true
      expect(subject.can_edit_booking? shipment, user).to eq false
    end

    it "allows if booking has been received, but is unlocked" do
      shipment.find_and_set_custom_value booking_unlocked_date, Time.zone.now
      shipment.booking_received_date = Time.zone.now


      expect(subject).to receive(:base_booking_permissions).with(shipment, user).and_return true
      expect(subject.can_edit_booking? shipment, user).to eq true
    end
  end

  describe "can_book_order_to_shipment?" do
    it "allows booking an order to a shipment if the shipment has no existing booking lines" do
      expect(subject.can_book_order_to_shipment? Order.new, Shipment.new).to eq true
    end

    context "with booked orders on shipment" do 
      let (:ship_to) { Factory(:address) }
      let (:delivery_location) { Factory(:port, unlocode: "UNLOC")}
      let (:booked_order) {
        o = Factory(:order, fob_point: "UNLOC")
        line = Factory(:order_line, order: o, ship_to: ship_to)
        o
      }
      let (:shipment) {
        s = Factory(:shipment, first_port_receipt_id: delivery_location.id, ship_to: ship_to)
        s.booking_lines.create! quantity: 1, order: booked_order, order_line: booked_order.order_lines.first, product: booked_order.order_lines.first.product
        s
      }

      let (:another_order) {
        o = Factory(:order, fob_point: "UNLOC")
        line = Factory(:order_line, order: o, ship_to: ship_to)
        o
      }

      it "allows booking if Delivery Location and Ship To matches" do
        expect(subject.can_book_order_to_shipment? another_order, shipment).to eq true
      end

      it "does not allow booking if order's delivery location does not match" do
        another_order.fob_point = "TIMBUKTU"
        expect(subject.can_book_order_to_shipment? another_order, shipment).to eq false
      end

      it "does not allow booking if shipment' delivery location does not match" do
        shipment.first_port_receipt = Factory(:port, unlocode: "LOCOD")
        expect(subject.can_book_order_to_shipment? another_order, shipment).to eq false
      end

      it "does not allow booking if ship to doesn't match" do
        another_order.order_lines.first.update_attributes! ship_to_id: Factory(:address)
        expect(subject.can_book_order_to_shipment? another_order, shipment).to eq false
      end

      it "doesn't allow booking unless all ship to lines on the order match whats on the shipment" do 
        another_order.order_lines.build ship_to_id: Factory(:address).id
        expect(subject.can_book_order_to_shipment? another_order, shipment).to eq false
      end
    end
  end
end
