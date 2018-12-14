require 'spec_helper'

describe Shipment do
  let :order_booking do
    obr = Class.new do
      def self.can_book?(ord, user); true; end
      def self.can_request_booking?(ord, user); true; end
      def self.can_revise_booking?(ord, user); true; end
      def self.can_edit_booking?(shipment, user); true; end
      def self.can_cancel?(shipment, user); true; end
      def self.can_uncancel?(shipment, user); true; end
    end
    OpenChain::Registries::OrderBookingRegistry.register obr
    OpenChain::Registries::ShipmentRegistry.register obr
    obr
  end
  describe '#generate_reference' do
    it 'should generate random reference number' do
      expect(Shipment.generate_reference).to match(/^[0-9A-F]{8}$/)
    end
    it 'should try again if reference is taken' do
      expect(SecureRandom).to receive(:hex).and_return('01234567','87654321')
      Factory(:shipment,reference:'01234567')
      expect(Shipment.generate_reference).to eq '87654321'
    end
  end

  describe "can_view?" do
    it "should not allow view if user not master and not linked to importer (even if the company is one of the other parties)" do
      imp = Factory(:company,importer:true)
      c = Factory(:company,vendor:true)
      s = Factory(:shipment,vendor:c,importer:imp)
      u = Factory(:user,shipment_view:true,company:c)
      expect(s.can_view?(u)).to be_falsey
   end
   it "should allow view if user from importer company" do
     imp = Factory(:company,importer:true)
     u = Factory(:user,shipment_view:true,company:imp)
     s = Factory(:shipment,importer:imp)
     expect(s.can_view?(u)).to be_truthy
   end
   it "should allow view if user from forwarder company" do
     fwd = Factory(:company,forwarder:true)
     imp = Factory(:company,importer:true)
     imp.linked_companies << fwd
     u = Factory(:user,shipment_view:true,company:fwd)
     s = Factory(:shipment,importer:imp,forwarder:fwd)
     expect(s.can_view?(u)).to be_truthy
   end
  end
  describe "search_secure" do
    before :each do
      @master_only = Factory(:shipment)
    end
    it "should allow vendor who is linked to shipment" do
      u = Factory(:user)
      s = Factory(:shipment,vendor:u.company)
      expect(Shipment.search_secure(u,Shipment).to_a).to eq [s]
    end
    it "should allow importer who is linked to shipment" do
      u = Factory(:user)
      s = Factory(:shipment,importer:u.company)
      expect(Shipment.search_secure(u,Shipment).to_a).to eq [s]
    end
    it "should allow agent who is linked to vendor on shipment" do
      u = Factory(:user)
      v = Factory(:company)
      v.linked_companies << u.company
      s = Factory(:shipment,vendor:v)
      expect(Shipment.search_secure(u,Shipment).to_a).to eq [s]
    end
    it "should allow master user" do
      u = Factory(:master_user)
      expect(Shipment.search_secure(u,Shipment).to_a).to eq [@master_only]
    end
    it "should allow carrier who is linked to shipment" do
      u = Factory(:user)
      s = Factory(:shipment,carrier:u.company)
      expect(Shipment.search_secure(u,Shipment).to_a).to eq [s]
    end
    it "should allow forwarder who is linked to shipment" do
      u = Factory(:user)
      s = Factory(:shipment,forwarder:u.company)
      expect(Shipment.search_secure(u,Shipment).to_a).to eq [s]
    end
    it "should not allow non linked user" do
      u = Factory(:user)
      expect(Shipment.search_secure(u,Shipment).to_a).to be_empty
    end
  end

  describe "can_cancel?" do
    it "should call registry method" do
      u = Factory(:user)
      s = Factory(:shipment)
      expect(OpenChain::Registries::ShipmentRegistry).to receive(:can_cancel?).with(s, u).and_return true
      s.can_cancel? u
    end
  end

  describe "cancel_shipment!" do
    let (:user) { Factory(:user) }
    let (:shipment) { Factory(:shipment) }

    it "should set cancel fields" do
      expect(shipment).to receive(:create_snapshot_with_async_option).with false, user, nil, nil
      expect(OpenChain::EventPublisher).to receive(:publish).with(:shipment_cancel, shipment)
      expect(OpenChain::Registries::ShipmentRegistry).to receive(:cancel_shipment_hook).with(shipment, user)
      now = Time.zone.parse("2018-09-10 12:00")
      Timecop.freeze(now) { shipment.cancel_shipment! user }
      
      shipment.reload
      expect(shipment.canceled_date).to eq now
      expect(shipment.canceled_by).to eq user
    end

    it "should set canceled_order_line_id for linked orders and remove shipment_line_id from piece_sets" do
      expect(shipment).to receive(:create_snapshot_with_async_option)
      expect(OpenChain::EventPublisher).to receive(:publish).with(:shipment_cancel, shipment)
      expect(OpenChain::Registries::ShipmentRegistry).to receive(:cancel_shipment_hook).with(shipment, user)
      p = Factory(:product)
      ol = Factory(:order_line,product:p,quantity:100)
      sl1 = shipment.shipment_lines.build(quantity:5)
      sl2 = shipment.shipment_lines.build(quantity:10)
      [sl1,sl2].each do |sl|
        sl.product = p
        sl.linked_order_line_id = ol.id
        sl.save!
      end
      #merge the two piece sets but don't delete so we don't have to check if they're linked
      #to other things
      expect{shipment.cancel_shipment!(user)}.to change(PieceSet,:count).from(2).to(0)
      [sl1,sl2].each do |sl|
        sl.reload
        expect(sl.canceled_order_line).to eq ol
      end
    end

    it "allows passing snapshot context and canceled date" do
      expect(shipment).to receive(:create_snapshot_with_async_option).with true, user, nil, "context"
      shipment.cancel_shipment! user, async_snapshot: true, canceled_date: Time.zone.parse("2018-09-10 12:00"), snapshot_context: "context"

      shipment.reload
      expect(shipment.canceled_date).to eq Time.zone.parse("2018-09-10 12:00")
      expect(shipment.canceled_by).to eq user
    end
  end

  describe "can_uncancel?" do
    it "should call registry method" do
      u = Factory(:user)
      s = Factory(:shipment)
      expect(OpenChain::Registries::ShipmentRegistry).to receive(:can_uncancel?).with(s, u).and_return true
      s.can_uncancel? u
    end
  end

  describe "uncancel_shipment!" do
    it "should remove cancellation" do
      u = Factory(:user)
      s = Factory(:shipment,canceled_by:u,canceled_date:Time.now,cancel_requested_at:Time.now,cancel_requested_by:u)
      expect(s).to receive(:create_snapshot_with_async_option).with false, u
      s.uncancel_shipment! u
      s.reload
      expect(s.canceled_by).to be_nil
      expect(s.canceled_date).to be_nil
      expect(s.cancel_requested_at).to be_nil
      expect(s.cancel_requested_by).to be_nil
    end
    it "should restore cancelled order line links" do
      u = Factory(:user)
      s = Factory(:shipment)
      expect(s).to receive(:create_snapshot_with_async_option).with false, u
      p = Factory(:product)
      ol = Factory(:order_line,product:p,quantity:100)
      sl1 = s.shipment_lines.build(quantity:5)
      sl2 = s.shipment_lines.build(quantity:10)
      [sl1,sl2].each do |sl|
        sl.product = p
        sl.canceled_order_line_id = ol.id
        sl.save!
      end
      #merge the two piece sets but don't delete so we don't have to check if they're linked
      #to other things
      expect{s.uncancel_shipment!(u)}.to change(PieceSet.where(order_line_id:ol.id),:count).from(0).to(2)
      [sl1,sl2].each do |sl|
        sl.reload
        expect(sl.order_lines.to_a).to eq [ol]
      end
    end
  end

  describe '#request_cancel' do
    let (:shipment) { Factory(:shipment) }
    let (:user) { Factory(:user) }

    it "should call hook" do
      expect(OpenChain::Registries::OrderBookingRegistry).to receive(:post_request_cancel_hook).with(shipment, user)
      expect(shipment).to receive(:create_snapshot_with_async_option).with(false, user)
      now = Time.zone.now
      Timecop.freeze(now) { shipment.request_cancel! user }

      expect(shipment.cancel_requested_by).to eq user
      expect(shipment.cancel_requested_at).to eq now
    end
  end

  describe "request booking" do
    it "should set booking fields" do
      u = User.new
      s = Shipment.new
      expect(s).to receive(:save!)
      expect(s).to receive(:create_snapshot_with_async_option).with false, u
      expect(OpenChain::EventPublisher).to receive(:publish).with(:shipment_booking_request,s)
      expect(OpenChain::Registries::OrderBookingRegistry).to receive(:request_booking_hook).with(s, u)
      s.request_booking! u
      expect(s.booking_received_date).to_not be_nil
      expect(s.booking_requested_by).to eq u
      expect(s.booking_request_count).to eq 1
    end
  end

  describe "can_request_booking?" do
    it "defers to order booking registry" do
      s = Shipment.new
      u = instance_double(User)
      expect(OpenChain::Registries::OrderBookingRegistry).to receive(:can_request_booking?).with(s, u).and_return true
      expect(s.can_request_booking?(u)).to be true
    end
  end

  describe "can_approve_booking?" do
    it "should allow approval for importer user who can edit shipment" do
      u = Factory(:user,shipment_edit:true,company:Factory(:company,importer:true))
      s = Shipment.new(booking_received_date:Time.now)
      s.importer = u.company
      allow(s).to receive(:can_edit?).and_return true
      expect(s.can_approve_booking?(u)).to be_truthy
    end
    it "should allow approval for master user who can edit shipment" do
      u = Factory(:master_user,shipment_edit:true)
      s = Shipment.new(booking_received_date:Time.now)
      expect(s).to receive(:can_edit?).with(u).and_return true
      expect(s.can_approve_booking?(u)).to be_truthy
    end
    it "should not allow approval for user who cannot edit shipment" do
      u = Factory(:master_user,shipment_edit:true)
      s = Shipment.new(booking_received_date:Time.now)
      expect(s).to receive(:can_edit?).with(u).and_return false
      expect(s.can_approve_booking?(u)).to be_falsey
    end
    it "should not allow approval for user from a different associated company" do
      u = Factory(:user,shipment_edit:true,company:Factory(:company,importer:true))
      s = Shipment.new(booking_received_date:Time.now)
      s.vendor = u.company
      allow(s).to receive(:can_edit?).and_return true
      expect(s.can_approve_booking?(u)).to be_falsey
    end
    it "should not allow approval when booking not received" do
      u = Factory(:master_user,shipment_edit:true)
      s = Shipment.new(booking_received_date:nil)
      allow(s).to receive(:can_edit?).and_return true
      expect(s.can_approve_booking?(u)).to be_falsey
    end
    it "should not allow if booking has been confirmed" do
      u = Factory(:master_user,shipment_edit:true)
      s = Shipment.new(booking_received_date:Time.now,booking_confirmed_date:Time.now)
      allow(s).to receive(:can_edit?).and_return true # make sure we're not testing the wrong thing
      expect(s.can_approve_booking?(u)).to be_falsey
    end
  end

  describe "approve_booking!" do
    it "should set booking_approved_date and booking_approved_by" do
      u = Factory(:user)
      s = Factory(:shipment)
      expect(s).to receive(:create_snapshot_with_async_option).with false, u
      expect(OpenChain::EventPublisher).to receive(:publish).with(:shipment_booking_approve,s)
      s.approve_booking! u
      s.reload
      expect(s.booking_approved_date).to_not be_nil
      expect(s.booking_approved_by).to eq u
    end
  end

  describe "can_confirm_booking?" do
    it "should allow confirmation for carrier user who can edit shipment" do
      u = Factory(:user,shipment_edit:true,company:Factory(:company,carrier:true))
      s = Shipment.new(booking_received_date:Time.now)
      allow(s).to receive(:can_edit?).and_return true
      s.carrier = u.company
      expect(s.can_confirm_booking?(u)).to be_truthy
    end
    it "should allow confirmation for master user who can edit shipment" do
      u = Factory(:master_user,shipment_edit:true)
      s = Shipment.new(booking_received_date:Time.now)
      expect(s).to receive(:can_edit?).with(u).and_return true
      expect(s.can_confirm_booking?(u)).to be_truthy
    end
    it "should not allow confirmation for user who cannot edit shipment" do
      u = Factory(:master_user,shipment_edit:false)
      s = Shipment.new(booking_received_date:Time.now)
      expect(s).to receive(:can_edit?).with(u).and_return false
      expect(s.can_confirm_booking?(u)).to be_falsey
    end
    it "should not allow confirmation for user who can edit shipment but isn't carrier or master" do
      u = Factory(:user,shipment_edit:true,company:Factory(:company,vendor:true))
      s = Shipment.new(booking_received_date:Time.now)
      allow(s).to receive(:can_edit?).and_return true
      s.vendor = u.company
      expect(s.can_confirm_booking?(u)).to be_falsey
    end
    it "should not allow confirmation when booking has not been received" do
      u = Factory(:master_user,shipment_edit:true)
      s = Shipment.new(booking_received_date:nil)
      allow(s).to receive(:can_edit?).and_return true
      expect(s.can_confirm_booking?(u)).to be_falsey
    end
    it "should not allow if booking already confiremd" do
      u = Factory(:master_user,shipment_edit:true)
      s = Shipment.new(booking_received_date:Time.now,booking_confirmed_date:Time.now)
      allow(s).to receive(:can_edit?).and_return true #make sure we're not accidentally testing the wrong thing
      expect(s.can_confirm_booking?(u)).to be_falsey
    end
  end
  describe "confirm booking" do
    let (:user) { Factory(:user) }
    let (:shipment) { 
      s = Factory(:shipment)
      Factory(:shipment_line,shipment:s,quantity:50)
      Factory(:shipment_line,shipment:s,quantity:100)

      s
    }
    it "should set booking confirmed date and booking confirmed by and booked quantity" do
      expect(shipment).to receive(:create_snapshot_with_async_option).with false, user
      expect(OpenChain::EventPublisher).to receive(:publish).with(:shipment_booking_confirm,shipment)
      shipment.confirm_booking! user
      shipment.reload
      expect(shipment.booking_confirmed_date).to_not be_nil
      expect(shipment.booking_confirmed_by).to eq user
      expect(shipment.booked_quantity).to eq 150
    end

    it "utilizes booking lines by default to calculate booked quantity" do
      shipment.booking_lines << BookingLine.new(line_number: 1, quantity: 100, product: shipment.shipment_lines.first.product)
      shipment.booking_lines << BookingLine.new(line_number: 2, quantity: 100, product: shipment.shipment_lines.first.product)

      shipment.confirm_booking! user
      expect(shipment.booked_quantity).to eq 200
    end
  end

  describe "can_revise_booking?" do
    it "defers to booking registry" do
      user = User.new
      shipment = Shipment.new
      expect(OpenChain::Registries::OrderBookingRegistry).to receive(:can_revise_booking?).with(shipment, user).and_return true
      expect(shipment.can_revise_booking? user).to eq true
    end
  end

  describe "revise booking" do
    it "should remove received, requested, approved and confirmed date and 'by' fields" do
      u = Factory(:user)
      original_receive= Time.zone.now
      s = Factory(:shipment,booking_approved_by:u,booking_requested_by:u,booking_confirmed_by:u,booking_received_date:original_receive,booking_approved_date:Time.now,booking_confirmed_date:Time.now,booking_request_count:1)
      expect(s).to receive(:create_snapshot_with_async_option).with(false,u)
      expect(OpenChain::Registries::OrderBookingRegistry).to receive(:revise_booking_hook).with(s, u)
      now = Time.zone.now
      Timecop.freeze(now) { s.revise_booking! u }
      s.reload
      expect(s.booking_approved_by).to be_nil
      expect(s.booking_approved_date).to be_nil
      expect(s.booking_confirmed_by).to be_nil
      expect(s.booking_confirmed_date).to be_nil
      expect(s.booking_received_date.to_i).to eq original_receive.to_i
      expect(s.booking_requested_by).to eq u
      expect(s.booking_revised_date.to_i).to eq now.to_i
      expect(s.booking_request_count).to eq 2
    end
  end

  context 'shipment instructions' do
    describe '#can_send_shipment_instructions?' do
      let :shipment_without_lines do
        s = Shipment.new(vendor:Company.new,booking_received_date:Time.now)
        allow(s).to receive(:can_edit?).and_return true
        s
      end
      let :shipment do
        shipment_without_lines.shipment_lines.build(line_number:1)
        shipment_without_lines
      end
      let :user do
        u = User.new
        u.company = shipment_without_lines.vendor
        u
      end
      it "should allow if user is from vendor and booking has been sent and shipment lines exist and user can edit" do
        expect(shipment.can_send_shipment_instructions?(user)).to be_truthy
      end
      it "should not allow if user cannot edit" do
        expect(shipment).to receive(:can_edit?).with(user).and_return false
        expect(shipment.can_send_shipment_instructions?(user)).to be_falsey
      end
      it "should not allow if shipment does not have lines" do
        expect(shipment_without_lines.can_send_shipment_instructions?(user)).to be_falsey
      end
      it "should not allow if user is not from vendor" do
        user.company = Company.new
        expect(shipment.can_send_shipment_instructions?(user)).to be_falsey
      end
      it "should not allow if booking has not been sent" do
        shipment.booking_received_date = nil
        expect(shipment.can_send_shipment_instructions?(user)).to be_falsey
      end
      it "should not allow if shipment is canceled" do
        shipment.canceled_date = Time.now
        expect(shipment.can_send_shipment_instructions?(user)).to be_falsey
      end
    end
    describe '#send_shipment_instructions!' do
      it "should set shipment instructions fields, publish event, and create snapshot" do
        s = Factory(:shipment)
        u = Factory(:user)
        expect(OpenChain::EventPublisher).to receive(:publish).with(:shipment_instructions_send,s)
        expect(s).to receive(:create_snapshot_with_async_option).with(false,u)

        s.send_shipment_instructions! u

        s.reload
        expect(s.shipment_instructions_sent_date).to_not be_nil
        expect(s.shipment_instructions_sent_by).to eq u
      end
    end
  end

  describe "can_add_remove_booking_lines?" do
    it "should allow adding lines if user can edit" do
      u = double('user')
      s = Shipment.new
      expect(s).to receive(:can_edit?).with(u).and_return true
      expect(s.can_add_remove_booking_lines?(u)).to be_truthy
    end
    it "should not allow adding lines if user cannot edit" do
      u = double('user')
      s = Shipment.new
      expect(s).to receive(:can_edit?).with(u).and_return false
      expect(s.can_add_remove_booking_lines?(u)).to be_falsey
    end

    context "editable shipment" do
      let(:shipment) do
        s = Shipment.new
        # stub can edit to make sure we're allowing anyone/anything to edit
        allow(s).to receive(:can_edit?).and_return true
        s
      end

      let(:user) { double("user") }

      it "should allow adding booking lines if booking is approved" do
        s = shipment.tap {|shp| shp.booking_approved_date = Time.now }
        expect(s.can_add_remove_booking_lines? user).to be_truthy
      end

      it "should allow adding lines if booking is confirmed" do
        s = shipment.tap {|shp| shp.booking_confirmed_date = Time.now }
        expect(s.can_add_remove_booking_lines? user).to be_truthy
      end

      it "disallows adding lines if shipment has actual shipment lines on it" do
        s = shipment.tap {|shp| shp.shipment_lines.build }
        expect(s.can_add_remove_booking_lines?(user)).to be_falsey
      end
    end
  end

  describe "can_add_remove_shipment_lines?" do
    it "allows adding lines if user can edit" do
      u = double('user')
      s = Shipment.new
      expect(s).to receive(:can_edit?).with(u).and_return true
      expect(s.can_add_remove_shipment_lines?(u)).to be_truthy
    end

    it "disallows adding lines if user cannot edit" do
      u = double('user')
      s = Shipment.new
      expect(s).to receive(:can_edit?).with(u).and_return false
      expect(s.can_add_remove_shipment_lines?(u)).to be_falsey
    end
  end

  describe "available_orders" do
    it "should find nothing if importer not set" do
      expect(Shipment.new.available_orders(User.new)).to be_empty
    end
    context "with_data" do
      before(:each) do
        @imp = Factory(:company,importer:true)
        @vendor_1 = Factory(:company,vendor:true)
        @vendor_2 = Factory(:company,vendor:true)
        @order_1 = Factory(:order,importer:@imp,vendor:@vendor_1,approval_status:'Accepted')
        @order_2 = Factory(:order,importer:@imp,vendor:@vendor_2,approval_status:'Accepted')
        #never find this one because it's for a different importer
        @order_3 = Factory(:order,importer:Factory(:company,importer:true),vendor:@vendor_1,approval_status:'Accepted')
        @s = Shipment.new(importer_id:@imp.id)
      end
      it "should find all orders with approval_status == Accepted where user is importer if vendor isn't set" do
        #don't find because not accepted
        Factory(:order,importer:@imp,vendor:@vendor_1)
        u = Factory(:user,company:@imp,order_view:true)
        expect(@s.available_orders(u).to_a).to eq [@order_1,@order_2]
      end
      it "should find all orders for vendor with approval_status == Accepted user is importer " do
        u = Factory(:user,company:@vendor_1,order_view:true)
        expect(@s.available_orders(u).to_a).to eq [@order_1]
      end
      it "should find all orders where shipment.vendor == order.vendor and approval_status == Accepted if vendor is set" do
        u = Factory(:user,company:@imp,order_view:true)
        @s.vendor_id = @vendor_1.id
        expect(@s.available_orders(u).to_a).to eq [@order_1]
      end
      it "should not show orders that the user cannot see" do
        u = Factory(:user,company:@vendor_1,order_view:true)
        @s.vendor_id = @vendor_2.id
        expect(@s.available_orders(u).to_a).to be_empty
      end
      it "should not find closed orders" do
        @order_2.update_attributes(closed_at:Time.now)
        u = Factory(:user,company:@imp,order_view:true)
        expect(@s.available_orders(u).to_a).to eq [@order_1]
      end
    end

  end
  describe "commercial_invoices" do
    it "should find linked invoices" do
      sl_1 = Factory(:shipment_line,:quantity=>10)
      ol_1 = Factory(:order_line,:product=>sl_1.product,:order=>Factory(:order,:vendor=>sl_1.shipment.vendor),:quantity=>10,:price_per_unit=>3)
      cl_1 = Factory(:commercial_invoice_line,:commercial_invoice=>Factory(:commercial_invoice,:invoice_number=>"IN1"),:quantity=>10)
      sl_2 = Factory(:shipment_line,:quantity=>11,:shipment=>sl_1.shipment,:product=>sl_1.product)
      ol_2 = Factory(:order_line,:product=>sl_2.product,:order=>Factory(:order,:vendor=>sl_2.shipment.vendor),:quantity=>11,:price_per_unit=>2)
      cl_2 = Factory(:commercial_invoice_line,:commercial_invoice=>Factory(:commercial_invoice,:invoice_number=>"IN2"),:quantity=>11)
      PieceSet.create!(:shipment_line_id=>sl_1.id,:order_line_id=>ol_1.id,:commercial_invoice_line_id=>cl_1.id,:quantity=>10)
      PieceSet.create!(:shipment_line_id=>sl_2.id,:order_line_id=>ol_2.id,:commercial_invoice_line_id=>cl_2.id,:quantity=>11)

      s = Shipment.find(sl_1.shipment.id)

      expect(s.commercial_invoices.collect {|ci| ci.invoice_number}).to eq(["IN1","IN2"])
    end
    it "should only return unique invoices" do
      sl_1 = Factory(:shipment_line,:quantity=>10)
      ol_1 = Factory(:order_line,:product=>sl_1.product,:order=>Factory(:order,:vendor=>sl_1.shipment.vendor),:quantity=>10,:price_per_unit=>3)
      cl_1 = Factory(:commercial_invoice_line,:commercial_invoice=>Factory(:commercial_invoice,:invoice_number=>"IN1"),:quantity=>10)
      sl_2 = Factory(:shipment_line,:quantity=>11,:shipment=>sl_1.shipment,:product=>sl_1.product)
      ol_2 = Factory(:order_line,:product=>sl_2.product,:order=>Factory(:order,:vendor=>sl_2.shipment.vendor),:quantity=>11,:price_per_unit=>2)
      cl_2 = Factory(:commercial_invoice_line,:commercial_invoice=>cl_1.commercial_invoice,:quantity=>11)
      PieceSet.create!(:shipment_line_id=>sl_1.id,:order_line_id=>ol_1.id,:commercial_invoice_line_id=>cl_1.id,:quantity=>10)
      PieceSet.create!(:shipment_line_id=>sl_2.id,:order_line_id=>ol_2.id,:commercial_invoice_line_id=>cl_2.id,:quantity=>11)

      sl_1.reload
      ci = sl_1.shipment.commercial_invoices
      # need to to_a call below because of bug: https://github.com/rails/rails/issues/5554
      expect(ci.to_a.size).to eq(1)
      ci.first.invoice_number == "IN1"
    end
  end
  describe 'linkable attachments' do
    it 'should have linkable attachments' do
      s = Factory(:shipment,:reference=>'ordn')
      linkable = Factory(:linkable_attachment,:model_field_uid=>'shp_ref',:value=>'ordn')
      LinkedAttachment.create(:linkable_attachment_id=>linkable.id,:attachable=>s)
      s.reload
      expect(s.linkable_attachments.first).to eq(linkable)
    end
  end

  describe "available_products" do
    before :each do
      @imp = Factory(:importer)
      @product = Factory(:product, importer: @imp)
      @product2 = Factory(:product)
      @shipment = Factory(:shipment, importer: @imp)

    end

    it "limits available products to those sharing importers with the shipment and user's importer company" do
      user = Factory(:user, company: @imp)
      products = @shipment.available_products(user).all
      expect(products.size).to eq 1
    end

    it "limits available products to those sharing importers with the shipment and user's linked companies" do
      user = Factory(:user, company: Factory(:importer))
      user.company.linked_companies << @imp
      products = @shipment.available_products(user).all
      expect(products.size).to eq 1
    end
  end

  describe "can_edit_booking?" do
    it "calls through to order registry" do
      user = User.new
      shipment = Shipment.new
      expect(OpenChain::Registries::OrderBookingRegistry).to receive(:can_edit_booking?).with(shipment, user).and_return true
      expect(shipment.can_edit_booking? user).to eq true
    end
  end

  describe "get_requested_equipment_pieces" do
    it "splits 2 value fields (normal case)" do
      shp = Shipment.new
      shp.requested_equipment = " 5 ABCD\n   \n7 EFGH  "
      pieces = shp.get_requested_equipment_pieces
      expect(pieces).to_not be_nil
      expect(pieces.length).to eq(2)
      expect(pieces[0].length).to eq(2)
      expect(pieces[0][0]).to eq('5')
      expect(pieces[0][1]).to eq('ABCD')
      expect(pieces[1].length).to eq(2)
      expect(pieces[1][0]).to eq('7')
      expect(pieces[1][1]).to eq('EFGH')
    end

    it "handles nil value" do
      shp = Shipment.new
      shp.requested_equipment = nil
      pieces = shp.get_requested_equipment_pieces
      expect(pieces).to_not be_nil
      expect(pieces.length).to eq(0)
    end

    it "handles blank value" do
      shp = Shipment.new
      shp.requested_equipment = '    '
      pieces = shp.get_requested_equipment_pieces
      expect(pieces).to_not be_nil
      expect(pieces.length).to eq(0)
    end

    it "handles non-standard value" do
      shp = Shipment.new
      shp.requested_equipment = "4 2 ABCD"
      expect { shp.get_requested_equipment_pieces }.to raise_error("Bad requested equipment field, expected each line to have number and type like \"3 40HC\", got 4 2 ABCD.")
    end
  end

  describe "normalized_booking_mode" do
    let(:s) { Factory(:shipment, booking_mode: "Ocean - FCL" )}

    it "strips everything after the first whitespace" do
      expect(s.normalized_booking_mode).to eq "OCEAN"
    end

    it "returns nil if booking_mode blank" do
      s.update_attributes! booking_mode: nil
      expect(s.normalized_booking_mode).to be_nil
      s.update_attributes! booking_mode: ""
      expect(s.normalized_booking_mode).to be_nil
    end

    it "returns nil if booking_mode doesn't contain letters" do
      s.update_attributes! booking_mode: "$@#!"
      expect(s.normalized_booking_mode).to be_nil
    end
  end
end
