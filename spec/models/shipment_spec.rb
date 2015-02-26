require 'spec_helper'

describe Shipment do
  describe "can_view?" do
    it "should not allow view if user not master and linked to importer (even if the company is one of the other parties" do
      imp = Factory(:company)
      c = Factory(:company,vendor:true)
      s = Factory(:shipment,vendor:c,importer:imp)
      u = Factory(:user,shipment_view:true,company:c)
      expect(s.can_view?(u)).to be_false
   end
   it "should allow view if user from importer company" do
     imp = Factory(:company)
     u = Factory(:user,shipment_view:true,company:imp)
     s = Factory(:shipment,importer:imp)
     expect(s.can_view?(u)).to be_false
   end
  end
  describe :search_secure do
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
    it "should not allow non linked user" do
      u = Factory(:user)
      expect(Shipment.search_secure(u,Shipment).to_a).to be_empty
    end
  end

  describe "can_cancel?" do
    it "should allow master to cancel if can edit shipment" do
      u = Factory(:master_user,shipment_edit:true)
      s = Shipment.new
      s.should_receive(:can_edit?).with(u).and_return true
      expect(s.can_cancel?(u)).to be_true
    end
    it "should not allow cancel if cannot edit" do
      u = Factory(:master_user,shipment_edit:true)
      s = Shipment.new
      s.should_receive(:can_edit?).with(u).and_return false
      expect(s.can_cancel?(u)).to be_false
    end
    it "should not allow cancel if already canceled" do
      u = Factory(:master_user,shipment_edit:true)
      s = Shipment.new(canceled_date:Time.now)
      s.stub(:can_edit?).and_return true
      expect(s.can_cancel?(u)).to be_false
    end
    context :vendor do
      before :each do
        @u = Factory(:user,company:Factory(:company,vendor:true))
        @s = Shipment.new
        @s.vendor = @u.company
        @s.should_receive(:can_edit?).with(@u).and_return true
      end
      it "should allow vendor to cancel if not received" do
        expect(@s.can_cancel?(@u)).to be_true
      end
      it "should not allow vendor to cancel if received" do
        @s.booking_received_date = Time.now
        expect(@s.can_cancel?(@u)).to be_false
      end
    end
    context :importer do
      before :each do
        @u = Factory(:user,company:Factory(:company,importer:true))
        @s = Shipment.new
        @s.importer = @u.company
        @s.should_receive(:can_edit?).with(@u).and_return true
      end
      it "should allow importer to cancel if not confirmed" do
        expect(@s.can_cancel?(@u)).to be_true
      end
      it "should not allow importer to cancel if confirmed" do
        @s.booking_confirmed_date = Time.now
        expect(@s.can_cancel?(@u)).to be_false
      end
    end
    it "should allow carrier to cancel" do
      @u = Factory(:user,company:Factory(:company,carrier:true))
      @s = Shipment.new
      @s.carrier = @u.company
      @s.should_receive(:can_edit?).with(@u).and_return true
      @s.booking_confirmed_date = Time.now
      expect(@s.can_cancel?(@u)).to be_true
    end
  end
  describe "cancel_shipment!" do
    it "should set cancel fields" do
      u = Factory(:user)
      s = Factory(:shipment)
      s.should_receive(:create_snapshot_with_async_option).with false, u
      OpenChain::EventPublisher.should_receive(:publish).with(:shipment_cancel,s)
      s.cancel_shipment! u
      s.reload
      expect(s.canceled_date).to_not be_nil
      expect(s.canceled_by).to eq u
    end
    it "should set canceled_order_line_id for linked orders and remove shipment_line_id from piece_sets" do
      u = Factory(:user)
      s = Factory(:shipment)
      s.should_receive(:create_snapshot_with_async_option).with false, u
      OpenChain::EventPublisher.should_receive(:publish).with(:shipment_cancel,s)
      p = Factory(:product)
      ol = Factory(:order_line,product:p,quantity:100)
      sl1 = s.shipment_lines.build(quantity:5)
      sl2 = s.shipment_lines.build(quantity:10)
      [sl1,sl2].each do |sl|
        sl.product = p
        sl.linked_order_line_id = ol.id
        sl.save!
      end
      #merge the two piece sets but don't delete so we don't have to check if they're linked
      #to other things
      expect{s.cancel_shipment!(u)}.to change(PieceSet,:count).from(2).to(0)
      [sl1,sl2].each do |sl|
        sl.reload
        expect(sl.canceled_order_line).to eq ol
      end
    end
  end

  describe :can_uncancel? do
    it "should allow if can_cancel_by_role? & can_edit & has canceled_date" do
      u = double(:user)
      s = Shipment.new(canceled_date:Time.now)
      s.should_receive(:can_edit?).with(u).and_return true
      s.should_receive(:can_cancel_by_role?).with(u).and_return true
      expect(s.can_uncancel?(u)).to be_true
    end
    it "should not allow if cannot edit" do
      u = double(:user)
      s = Shipment.new(canceled_date:Time.now)
      s.stub(:can_cancel_by_role?).and_return true
      s.should_receive(:can_edit?).with(u).and_return false
      expect(s.can_uncancel?(u)).to be_false
    end
    it "should not allow if cannot cancel by role" do
      u = double(:user)
      s = Shipment.new(canceled_date:Time.now)
      s.stub(:can_edit?).and_return true
      s.should_receive(:can_cancel_by_role?).with(u).and_return false
      expect(s.can_uncancel?(u)).to be_false
    end
    it "should not allow if does not have canceled date" do
      u = double(:user)
      s = Shipment.new(canceled_date:nil)
      s.stub(:can_edit?).and_return true
      s.stub(:can_cancel_by_role?).and_return true
      expect(s.can_uncancel?(u)).to be_false
    end
  end
  describe :uncancel_shipment! do
    it "should remove cancellation" do
      u = Factory(:user)
      s = Factory(:shipment,canceled_by:u,canceled_date:Time.now)
      s.should_receive(:create_snapshot_with_async_option).with false, u
      s.uncancel_shipment! u
      s.reload
      expect(s.canceled_by).to be_nil
      expect(s.canceled_date).to be_nil
    end
    it "should restore cancelled order line links" do
      u = Factory(:user)
      s = Factory(:shipment)
      s.should_receive(:create_snapshot_with_async_option).with false, u
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

  describe "request booking" do
    it "should set booking received date and booking request by" do
      u = Factory(:user)
      s = Factory(:shipment)
      s.should_receive(:create_snapshot_with_async_option).with false, u
      OpenChain::EventPublisher.should_receive(:publish).with(:shipment_booking_request,s)
      s.request_booking! u
      s.reload
      expect(s.booking_received_date).to_not be_nil
      expect(s.booking_requested_by).to eq u
    end
  end

  describe "can_request_booking?" do
    it "should allow if user is from master & can view shipment" do
      expect(Shipment.new.can_request_booking?(Factory(:master_user,shipment_view:true))).to be_true
    end
    it "should allow if user is from vendor & can view shipment" do
      u = Factory(:user,shipment_view:true,company:Factory(:company,vendor:true))
      s = Shipment.new
      s.stub(:can_view?).and_return true
      s.vendor = u.company
      expect(s.can_request_booking?(u)).to be_true
    end
    it "should not allow if user cannot edit shipment" do
      u = Factory(:user,shipment_view:false)
      s = Shipment.new
      s.vendor = u.company
      expect(s.can_request_booking?(u)).to be_false
    end
    it "should not allow if user not from vendor or master" do
      u = Factory(:user,shipment_view:false)
      s = Shipment.new
      expect(s.can_request_booking?(u)).to be_false
    end
    it "should not allow if booking is approved" do
      u = Factory(:user,shipment_view:true,company:Factory(:company,vendor:true))
      s = Shipment.new(booking_approved_date:Time.now)
      s.stub(:can_view?).and_return true
      s.vendor = u.company
      expect(s.can_request_booking?(u)).to be_false
    end
  end

  describe "can_approve_booking?" do
    it "should allow approval for importer user who can edit shipment" do
      u = Factory(:user,shipment_edit:true,company:Factory(:company,importer:true))
      s = Shipment.new(booking_received_date:Time.now)
      s.importer = u.company
      s.stub(:can_edit?).and_return true
      expect(s.can_approve_booking?(u)).to be_true
    end
    it "should allow approval for master user who can edit shipment" do
      u = Factory(:master_user,shipment_edit:true)
      s = Shipment.new(booking_received_date:Time.now)
      s.should_receive(:can_edit?).with(u).and_return true
      expect(s.can_approve_booking?(u)).to be_true
    end
    it "should not allow approval for user who cannot edit shipment" do
      u = Factory(:master_user,shipment_edit:true)
      s = Shipment.new(booking_received_date:Time.now)
      s.should_receive(:can_edit?).with(u).and_return false
      expect(s.can_approve_booking?(u)).to be_false
    end
    it "should not allow approval for user from a different associated company" do
      u = Factory(:user,shipment_edit:true,company:Factory(:company,importer:true))
      s = Shipment.new(booking_received_date:Time.now)
      s.vendor = u.company
      s.stub(:can_edit?).and_return true
      expect(s.can_approve_booking?(u)).to be_false
    end
    it "should not allow approval when booking not received" do
      u = Factory(:master_user,shipment_edit:true)
      s = Shipment.new(booking_received_date:nil)
      s.stub(:can_edit?).and_return true
      expect(s.can_approve_booking?(u)).to be_false
    end
    it "should not allow if booking has been confirmed" do
      u = Factory(:master_user,shipment_edit:true)
      s = Shipment.new(booking_received_date:Time.now,booking_confirmed_date:Time.now)
      s.stub(:can_edit?).and_return true # make sure we're not testing the wrong thing
      expect(s.can_approve_booking?(u)).to be_false
    end
  end

  describe "approve_booking!" do
    it "should set booking_approved_date and booking_approved_by" do
      u = Factory(:user)
      s = Factory(:shipment)
      s.should_receive(:create_snapshot_with_async_option).with false, u
      OpenChain::EventPublisher.should_receive(:publish).with(:shipment_booking_approve,s)
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
      s.stub(:can_edit?).and_return true
      s.carrier = u.company
      expect(s.can_confirm_booking?(u)).to be_true
    end
    it "should allow confirmation for master user who can edit shipment" do
      u = Factory(:master_user,shipment_edit:true)
      s = Shipment.new(booking_received_date:Time.now)
      s.should_receive(:can_edit?).with(u).and_return true
      expect(s.can_confirm_booking?(u)).to be_true
    end
    it "should not allow confirmation for user who cannot edit shipment" do
      u = Factory(:master_user,shipment_edit:false)
      s = Shipment.new(booking_received_date:Time.now)
      s.should_receive(:can_edit?).with(u).and_return false
      expect(s.can_confirm_booking?(u)).to be_false
    end
    it "should not allow confirmation for user who can edit shipment but isn't carrier or master" do
      u = Factory(:user,shipment_edit:true,company:Factory(:company,vendor:true))
      s = Shipment.new(booking_received_date:Time.now)
      s.stub(:can_edit?).and_return true
      s.vendor = u.company
      expect(s.can_confirm_booking?(u)).to be_false
    end
    it "should not allow confirmation when booking has not been received" do
      u = Factory(:master_user,shipment_edit:true)
      s = Shipment.new(booking_received_date:nil)
      s.stub(:can_edit?).and_return true
      expect(s.can_confirm_booking?(u)).to be_false
    end
    it "should not allow if booking already confiremd" do
      u = Factory(:master_user,shipment_edit:true)
      s = Shipment.new(booking_received_date:Time.now,booking_confirmed_date:Time.now)
      s.stub(:can_edit?).and_return true #make sure we're not accidentally testing the wrong thing
      expect(s.can_confirm_booking?(u)).to be_false
    end
  end
  describe "confirm booking" do
    it "should set booking confirmed date and booking confirmed by and booked quantity" do
      u = Factory(:user)
      s = Factory(:shipment)
      Factory(:shipment_line,shipment:s,quantity:50)
      Factory(:shipment_line,shipment:s,quantity:100)
      s.should_receive(:create_snapshot_with_async_option).with false, u
      OpenChain::EventPublisher.should_receive(:publish).with(:shipment_booking_confirm,s)
      s.confirm_booking! u
      s.reload
      expect(s.booking_confirmed_date).to_not be_nil
      expect(s.booking_confirmed_by).to eq u
      expect(s.booked_quantity).to eq 150
    end
  end

  describe "can_revise_booking" do
    it "should allow user to revise if approved but not confirmed and user can request_booking" do
      u = double('u')
      s = Shipment.new(booking_approved_date:Time.now)
      s.should_receive(:can_request_booking?).with(u,true).and_return true
      s.stub(:can_approve_booking?).and_return false #make sure we're not testing the wrong thing
      s.stub(:can_confirm_booking?).and_return false #make sure we're not testing the wrong thing
      expect(s.can_revise_booking?(u)).to be_true
    end
    it "should allow user to revise if approved but not confirmed and user can approve_booking" do
      u = double('u')
      s = Shipment.new(booking_approved_date:Time.now)
      s.should_receive(:can_approve_booking?).with(u,true).and_return true
      s.stub(:can_request_booking?).and_return false #make sure we're not testing the wrong thing
      s.stub(:can_confirm_booking?).and_return false #make sure we're not testing the wrong thing
      expect(s.can_revise_booking?(u)).to be_true
    end

    it "should allow user to revise if confirmed and user can confirm_booking" do
      u = double('u')
      s = Shipment.new(booking_approved_date:Time.now,booking_confirmed_date:Time.now)
      s.should_receive(:can_confirm_booking?).with(u,true).and_return true
      s.stub(:can_approve_booking?).and_return false #make sure we're not testing the wrong thing
      s.stub(:can_request_booking?).and_return false #make sure we're not testing the wrong thing
      expect(s.can_revise_booking?(u)).to be_true
    end
    it "should not allow user to revise if confirmed and user cannot confirm_booking" do
      u = double('u')
      s = Shipment.new(booking_approved_date:Time.now,booking_confirmed_date:Time.now)
      s.should_receive(:can_confirm_booking?).with(u,true).and_return false
      s.stub(:can_approve_booking?).and_return true #make sure we're not testing the wrong thing
      s.stub(:can_request_booking?).and_return true #make sure we're not testing the wrong thing
      expect(s.can_revise_booking?(u)).to be_false
    end
    it "should not allow if not approved or confirmed" do #since it wouldn't be logical
      u = double('u')
      s = Shipment.new
      s.stub(:can_approve_booking?).and_return true #make sure we're not testing the wrong thing
      s.stub(:can_request_booking?).and_return true #make sure we're not testing the wrong thing
      s.stub(:can_confirm_booking?).and_return true #make sure we're not testing the wrong thing
      expect(s.can_revise_booking?(u)).to be_false
    end
  end
  describe "revise booking" do
    it "should remove received, requested, approved and confirmed date and 'by' fields" do
      u = Factory(:user)
      s = Factory(:shipment,booking_approved_by:u,booking_requested_by:u,booking_confirmed_by:u,booking_received_date:Time.now,booking_approved_date:Time.now,booking_confirmed_date:Time.now)
      s.should_receive(:create_snapshot_with_async_option).with(false,u)
      s.revise_booking! u
      s.reload
      expect(s.booking_approved_by).to be_nil
      expect(s.booking_approved_date).to be_nil
      expect(s.booking_confirmed_by).to be_nil
      expect(s.booking_confirmed_date).to be_nil
      expect(s.booking_received_date).to be_nil
      expect(s.booking_requested_by).to be_nil
    end
  end

  describe :can_add_remove_lines? do
    it "should allow adding lines if user can edit" do
      u = double('user')
      s = Shipment.new
      s.should_receive(:can_edit?).with(u).and_return true
      expect(s.can_add_remove_lines?(u)).to be_true
    end
    it "should not allow adding lines if user cannot edit" do
      u = double('user')
      s = Shipment.new
      s.should_receive(:can_edit?).with(u).and_return false
      expect(s.can_add_remove_lines?(u)).to be_false
    end
    it "should not allow adding lines if booking is approved" do
      u = double('user')
      s = Shipment.new(booking_approved_date:Time.now)
      s.stub(:can_edit?).and_return true #make sure we're not testing the wrong thing
      expect(s.can_add_remove_lines?(u)).to be_false
    end
    it "should not allow adding lines if booking is confirmed" do
      u = double('user')
      s = Shipment.new(booking_confirmed_date:Time.now)
      s.stub(:can_edit?).and_return true #make sure we're not testing the wrong thing
      expect(s.can_add_remove_lines?(u)).to be_false
    end
  end

  describe "available_orders" do
    it "should find nothing if importer not set" do
      expect(Shipment.new.available_orders(User.new)).to be_empty
    end
    context :with_data do
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

      s.commercial_invoices.collect {|ci| ci.invoice_number}.should == ["IN1","IN2"]
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
      ci.to_a.should have(1).invoice
      ci.first.invoice_number == "IN1"
    end
  end
  describe 'linkable attachments' do
    it 'should have linkable attachments' do
      s = Factory(:shipment,:reference=>'ordn')
      linkable = Factory(:linkable_attachment,:model_field_uid=>'shp_ref',:value=>'ordn')
      LinkedAttachment.create(:linkable_attachment_id=>linkable.id,:attachable=>s)
      s.reload
      s.linkable_attachments.first.should == linkable
    end
  end
end
