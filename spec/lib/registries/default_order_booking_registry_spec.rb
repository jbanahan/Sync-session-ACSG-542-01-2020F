describe OpenChain::Registries::DefaultOrderBookingRegistry do

  subject { described_class }

  describe "can_request_booking?" do
    it "should allow if user is from master & can view shipment" do
      expect(subject.can_request_booking?(Shipment.new, FactoryBot(:master_user, shipment_view:true))).to be_truthy
    end

    it "should allow if user is from vendor & can view shipment" do
      u = FactoryBot(:user, shipment_view:true, company:FactoryBot(:company, vendor:true))
      s = Shipment.new
      allow(s).to receive(:can_view?).and_return true
      s.vendor = u.company
      expect(subject.can_request_booking?(s, u)).to be_truthy
    end
    it "should not allow if user cannot edit shipment" do
      u = FactoryBot(:user, shipment_view:false)
      s = Shipment.new
      s.vendor = u.company
      expect(subject.can_request_booking?(s, u)).to be_falsey
    end
    it "should not allow if user not from vendor or master" do
      u = FactoryBot(:user, shipment_view:false)
      s = Shipment.new
      expect(subject.can_request_booking?(s, u)).to be_falsey
    end
    it "should not allow if booking is approved" do
      u = FactoryBot(:user, shipment_view:true, company:FactoryBot(:company, vendor:true))
      s = Shipment.new(booking_approved_date:Time.now)
      allow(s).to receive(:can_view?).and_return true
      s.vendor = u.company
      expect(subject.can_request_booking?(s, u)).to be_falsey
    end
  end

  describe "can_revise_booking?" do
    it "should allow user to revise if approved but not confirmed and user can request_booking" do
      u = instance_double(User)
      s = Shipment.new(booking_approved_date:Time.now)
      expect(subject).to receive(:default_can_request_booking?).with(s, u, true).and_return true
      allow(s).to receive(:can_approve_booking?).and_return false # make sure we're not testing the wrong thing
      allow(s).to receive(:can_confirm_booking?).and_return false # make sure we're not testing the wrong thing
      expect(subject.can_revise_booking?(s, u)).to be_truthy
    end
    it "should allow user to revise if approved but not confirmed and user can approve_booking" do
      u = instance_double(User)
      s = Shipment.new(booking_approved_date:Time.now)
      expect(s).to receive(:can_approve_booking?).with(u, true).and_return true
      allow(s).to receive(:can_confirm_booking?).and_return false # make sure we're not testing the wrong thing
      expect(subject.can_revise_booking?(s, u)).to be_truthy
    end

    it "should allow user to revise if confirmed and user can confirm_booking" do
      u = instance_double(User)
      s = Shipment.new(booking_approved_date:Time.now, booking_confirmed_date:Time.now)
      expect(s).to receive(:can_confirm_booking?).with(u, true).and_return true
      allow(s).to receive(:can_approve_booking?).and_return false # make sure we're not testing the wrong thing
      expect(subject.can_revise_booking?(s, u)).to be_truthy
    end
    it "should not allow user to revise if confirmed and user cannot confirm_booking" do
      u = instance_double(User)
      s = Shipment.new(booking_approved_date:Time.now, booking_confirmed_date:Time.now)
      expect(s).to receive(:can_confirm_booking?).with(u, true).and_return false
      allow(s).to receive(:can_approve_booking?).and_return true # make sure we're not testing the wrong thing
      expect(subject.can_revise_booking?(s, u)).to be_falsey
    end
    it "should not allow if not approved or confirmed" do
      u = instance_double(User)
      s = Shipment.new
      allow(s).to receive(:can_approve_booking?).and_return true # make sure we're not testing the wrong thing
      allow(s).to receive(:can_confirm_booking?).and_return true # make sure we're not testing the wrong thing
      expect(subject.can_revise_booking?(s, u)).to be_falsey
    end
    it "does not allow revising bookings with shipment lines" do
      u = instance_double(User)
      s = Shipment.new(booking_approved_date:Time.now)
      s.shipment_lines.build
      expect(subject.can_revise_booking?(s, u)).to be_falsey
    end
  end

  describe "can_edit_booking?" do
    it "allows editing booking if user can edit shipments" do
      s = Shipment.new
      u = instance_double(User)
      expect(s).to receive(:can_edit?).with(u).and_return true
      expect(subject.can_edit_booking? s, u).to eq true
    end
  end

  describe "can_book_order_to_shipment?" do
    it "allows all orders to be booked to shipments" do
      expect(subject.can_book_order_to_shipment? nil, nil).to eq true
    end
  end

  describe "open_bookings_hook" do
    let! (:shipment) { FactoryBot(:shipment) }

    it "returns shipments with booking instructions not sent" do
      query = subject.open_bookings_hook(nil, Shipment.where("1=1"), nil)
      expect(query.all).to include shipment
    end

    it "does not return shipments with booking instructions sent" do
      shipment.update_attributes! shipment_instructions_sent_date: Time.zone.now
      query = subject.open_bookings_hook(nil, Shipment.where("1=1"), nil)
      expect(query.all).not_to include shipment
    end
  end

  describe "book_from_order_hook" do
    let (:order) {
      o = Order.new
      o.ship_from_id = 10
      o
    }

    it "defaults shipment data on a new shipment" do
      shipment = {}
      subject.book_from_order_hook shipment, order, []

      expect(shipment[:shp_ship_from_id]).to eq 10
    end

    it "defaults shipment data for an existing shipment" do
      shipment = {id: 1}
      subject.book_from_order_hook shipment, order, []

      expect(shipment[:shp_ship_from_id]).to be_nil
    end
  end
end