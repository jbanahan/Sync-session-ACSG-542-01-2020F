require 'spec_helper'

describe Order do
  before :each do
    OpenChain::OrderAcceptanceRegistry.clear
  end
  describe 'display_order_number' do
    it "shoud show order_number if no customer order number" do
      expect(Order.new(order_number:'abc').display_order_number).to eq 'abc'
    end
    it "should show customer order number" do
      expect(Order.new(order_number:'abc',customer_order_number:'def').display_order_number).to eq 'def'
    end
  end
  describe 'post_create_logic' do
    before :each do
      @u = Factory(:master_user)
      @o = Factory(:order)
      expect(OpenChain::EventPublisher).to receive(:publish).with(:order_create,@o)
    end

    it 'should run' do
      expect(@o).to receive(:create_snapshot_with_async_option).with(false,@u)
      @o.post_create_logic!(@u)
    end
    it 'should run async' do
      expect(@o).to receive(:create_snapshot_with_async_option).with(true,@u)
      @o.post_create_logic!(@u,true)
    end
    it 'should run async method' do
      expect(@o).to receive(:create_snapshot_with_async_option).with(true,@u)
      @o.async_post_create_logic!(@u)
    end
  end
  describe 'post_update_logic' do
    before :each do
      @u = Factory(:master_user)
      @o = Factory(:order)
      expect(OpenChain::EventPublisher).to receive(:publish).with(:order_update,@o)
    end

    it 'should run' do
      expect(@o).to receive(:create_snapshot_with_async_option).with(false,@u)
      @o.post_update_logic!(@u)
    end
    it 'should run async' do
      expect(@o).to receive(:create_snapshot_with_async_option).with(true,@u)
      @o.post_update_logic!(@u,true)
    end
    it 'should run async method' do
      expect(@o).to receive(:create_snapshot_with_async_option).with(true,@u)
      @o.async_post_update_logic!(@u)
    end
  end
  describe 'accept' do
    before :each do
      @o = Factory(:order)
      @v = Factory(:company,vendor:true)
      @u = Factory(:user,company:@v)
      @t = Time.now
      allow(Time).to receive(:now).and_return @t
      expect(OpenChain::EventPublisher).to receive(:publish).with(:order_accept,@o)
    end
    it 'should accept' do
      expect(@o).to receive(:create_snapshot_with_async_option).with false, @u
      @o.accept! @u
      @o.reload
      expect(@o.approval_status).to eq 'Accepted'
      expect(@o.accepted_by).to eq @u
      expect(@o.accepted_at).to_not be_nil
    end
    it 'should accept async' do
      expect(@o).to receive(:create_snapshot_with_async_option).with true, @u
      @o.async_accept! @u
      @o.reload
      expect(@o.approval_status).to eq 'Accepted'
      expect(@o.accepted_by).to eq @u
      expect(@o.accepted_at).to_not be_nil
    end
  end
  describe 'can_be_accepted?' do
    it 'should return true if all OrderAcceptanceRegistry tests returns true' do
      o = Order.new
      d1 = double('oa1')
      d2 = double('oa2')
      [d1,d2].each {|d| expect(d).to receive(:can_be_accepted?).with(o).and_return true}
      expect(OpenChain::OrderAcceptanceRegistry).to receive(:registered).and_return [d1,d2]

      expect(o.can_be_accepted?).to be true
    end
    it 'should return false if any OrderAcceptanceRegistry test returns false' do
      o = Order.new
      d1 = double('oa1')
      d2 = double('oa2')
      expect(d1).to receive(:can_be_accepted?).with(o).and_return true
      expect(d2).to receive(:can_be_accepted?).with(o).and_return false
      expect(OpenChain::OrderAcceptanceRegistry).to receive(:registered).and_return [d1,d2]

      expect(o.can_be_accepted?).to be false
    end
  end
  describe 'unaccept' do
    before :each do
      @t = Time.now
      allow(Time).to receive(:now).and_return @t
      @v = Factory(:company,vendor:true)
      @u = Factory(:user,company:@v)
      @o = Factory(:order,approval_status:'Approved',accepted_by:@u,accepted_at:@t)
      expect(OpenChain::EventPublisher).to receive(:publish).with(:order_unaccept,@o)
    end

    it 'should unaccept' do
      expect(@o).to receive(:create_snapshot_with_async_option).with false, @u
      @o.unaccept! @u
      @o.reload
      expect(@o.approval_status).to be_nil
      expect(@o.accepted_by).to be_nil
      expect(@o.accepted_at).to be_nil
    end

    it 'should unaccept async' do
      expect(@o).to receive(:create_snapshot_with_async_option).with true, @u
      @o.async_unaccept! @u
      @o.reload
      expect(@o.approval_status).to be_nil
      expect(@o.accepted_by).to be_nil
      expect(@o.accepted_at).to be_nil
    end
  end
  describe 'can_accept' do
    context 'default behavior' do
      before :each do
        @g = Group.new(system_code:'ORDERACCEPT')
      end
      it "should not allow if user not in 'ORDERACCEPT' group" do
        v = Company.new(vendor:true)
        u = User.new
        u.company = v
        o = Order.new(vendor:v)
        expect(o.can_accept?(u)).to be_falsey
      end
      it "should allow vendor user to accept" do
        v = Company.new(vendor:true)
        u = User.new
        u.add_to_group_cache @g
        u.company = v
        o = Order.new(vendor:v)
        expect(o.can_accept?(u)).to be_truthy
      end
      it "should allow agent to accept" do
        a = Company.new(agent:true)
        u = User.new
        u.add_to_group_cache @g
        u.company = a
        o = Order.new(agent:a)
        expect(o.can_accept?(u)).to be_truthy
      end
      it "should allow admin user to accept" do
        c = Company.new(vendor:true)
        u = User.new
        u.add_to_group_cache @g
        u.company = c
        u.admin = true
        o = Order.new
        allow(o).to receive(:can_edit?).and_return true
        expect(o.can_accept?(u)).to be_truthy
      end
      it "should not allow user who is not admin to accept" do
        c = Company.new(vendor:true)
        u = User.new
        u.add_to_group_cache @g
        u.company = c
        u.admin = false
        o = Order.new
        allow(o).to receive(:can_edit?).and_return true
        expect(o.can_accept?(u)).to be_falsey
      end
    end
    it 'should not call default behavior if acceptance registry has values' do
      c = Class.new do
        def self.can_accept? ord, user
          return true
        end
      end
      OpenChain::OrderAcceptanceRegistry.register(c)
      # This would fail under default behavior
      v = Company.new(vendor:true)
      u = User.new
      u.company = v
      o = Order.new(vendor:v)
      expect(o.can_accept?(u)).to be_truthy
    end
  end
  describe 'close' do
    before :each do
      @o = Factory(:order)
      @u = Factory(:user)
      @t = Time.now
      allow(Time).to receive(:now).and_return @t
      expect(OpenChain::EventPublisher).to receive(:publish).with(:order_close,@o)
    end
    it 'should close' do
      @o.close! @u
      @o = Order.find @o.id
      expect(@o.closed_at.to_i).to eq @t.to_i
      expect(@o.closed_by).to eq @u
      expect(@o.entity_snapshots.count).to eq 1
    end
    it 'should close async' do
      @o.async_close! @u
      expect(@o.closed_at).to eq @t
      expect(@o.closed_by).to eq @u
      expect(@o.entity_snapshots.count).to eq 1
    end
  end
  describe 'reopen' do
    before :each do
      @u = Factory(:user)
      @o = Factory(:order,closed_at:Time.now,closed_by:@u)
      @t = Time.now
      allow(Time).to receive(:now).and_return @t
      expect(OpenChain::EventPublisher).to receive(:publish).with(:order_reopen,@o)
    end
    it 'should reopen' do
      @o.reopen! @u
      @o = Order.find @o.id
      expect(@o.closed_at).to be_nil
      expect(@o.closed_by).to be_nil
      expect(@o.entity_snapshots.count).to eq 1
    end
    it 'should reopen_async' do
      @o.async_reopen! @u
      expect(@o.closed_at).to be_nil
      expect(@o.closed_by).to be_nil
      expect(@o.entity_snapshots.count).to eq 1
    end
  end
  describe 'can_close?' do
    before :each do
      @o = Factory(:order,importer:Factory(:company,importer:true))
    end
    it "should allow if user can edit orders and is from importer" do
      u = Factory(:user,order_edit:true,company:@o.importer)
      expect(@o.can_close?(u)).to be_truthy
    end
    it "should allow if user can edit orders and is from master" do
      u = Factory(:master_user,order_edit:true)
      expect(@o.can_close?(u)).to be_truthy
    end
    it "should not allow if user can edit orders and is from vendor" do
      u = Factory(:user,order_edit:true)
      @o.update_attributes(vendor_id:u.company_id)
      expect(@o.can_close?(u)).to be_falsey
    end
    it "should not allow if user cannot edit orders" do
      u = Factory(:user,order_edit:false,company:@o.importer)
      expect(@o.can_close?(u)).to be_falsey
    end
  end
  describe 'linkable attachments' do
    it 'should have linkable attachments' do
      o = Factory(:order,:order_number=>'ordn')
      linkable = Factory(:linkable_attachment,:model_field_uid=>'ord_ord_num',:value=>'ordn')
      LinkedAttachment.create(:linkable_attachment_id=>linkable.id,:attachable=>o)
      o.reload
      expect(o.linkable_attachments.first).to eq(linkable)
    end
  end

  describe 'all attachments' do
    before :each do
      @o = Factory(:order)
    end
    it 'should return all_attachments when only regular attachments' do
      a = @o.attachments.create!
      all = @o.all_attachments
      expect(all.size).to eq(1)
      expect(all.first).to eq(a)
    end
    it 'should return all_attachments when only linked attachents' do
      linkable = Factory(:linkable_attachment,:model_field_uid=>'ord_ord_num',:value=>@o.order_number)
      a = linkable.build_attachment
      a.save!
      @o.linked_attachments.create!(:linkable_attachment_id=>linkable.id)
      all = @o.all_attachments
      expect(all.size).to eq(1)
      expect(all.first).to eq(a)
    end
    it 'should return all_attachments when both attachments' do
      a = @o.attachments.create!
      linkable = Factory(:linkable_attachment,:model_field_uid=>'ord_ord_num',:value=>@o.order_number)
      linkable_a = linkable.build_attachment
      linkable_a.save!
      @o.linked_attachments.create!(:linkable_attachment_id=>linkable.id)
      all = @o.all_attachments
      expect(all.size).to eq(2)
      expect(all).to include(a)
      expect(all).to include(linkable_a)
    end
    it 'should return empty array when no attachments' do
      expect(@o.all_attachments).to be_empty
    end
  end

  describe "create_unique_po_number" do
    it "uses importer identifier in po number" do
      o = Order.new customer_order_number: "PO", importer: Company.new(:system_code => "SYS_CODE", :alliance_customer_number=> "ALL_CODE", :fenix_customer_number=>"FEN_CODE")
      expect(o.create_unique_po_number).to eq "SYS_CODE-PO"
    end
    it "uses importer alliance code after sys code" do
      o = Order.new customer_order_number: "PO", importer: Company.new(:alliance_customer_number=> "ALL_CODE", :fenix_customer_number=>"FEN_CODE")
      expect(o.create_unique_po_number).to eq "ALL_CODE-PO"
    end
    it "uses fenix code after alliance code" do
      o = Order.new customer_order_number: "PO", importer: Company.new(:fenix_customer_number=>"FEN_CODE")
      expect(o.create_unique_po_number).to eq "FEN_CODE-PO"
    end
    it "uses vendor sys code" do
      o = Order.new customer_order_number: "PO", vendor: Company.new(:system_code => "SYS_CODE")
      expect(o.create_unique_po_number).to eq "SYS_CODE-PO"
    end
  end

  describe "can_view?" do
    let (:order) { Order.new }

    context :importer do
      before :each do
        @importer = Factory(:company, importer: true)
        order.importer = @importer
        @user = Factory(:user, company: @importer)
        allow(@user).to receive(:view_orders?).and_return true
      end

      it "allows an importer to view their orders" do
        expect(order.can_view? @user).to be_truthy
      end

      it "allows user to view if linked company is order importer" do
        order.importer = Factory(:company, importer: true)

        @user.company.linked_company_ids = [order.importer.id]
        expect(order.can_view? @user).to be_truthy
      end

      it "allows user to view if linked company is order vendor" do
        order.vendor = Factory(:company, vendor: true)

        @user.company.linked_company_ids = [order.vendor.id]
        expect(order.can_view? @user).to be_truthy
      end

      it "allows a vendor to view their orders" do
        vendor = Factory(:company, vendor: true)
        order.vendor = vendor
        u = Factory(:user, company: vendor)
        allow(u).to receive(:view_orders?).and_return true

        expect(order.can_view? u).to be_truthy
      end
    end

    context :vendor do
      before :each do
        @vendor = Factory(:company, vendor: true)
        order.vendor = @vendor
        @user = Factory(:user, company: @vendor)
        allow(@user).to receive(:view_orders?).and_return true
      end

      it "allows a vendor to view their orders" do
        expect(order.can_view? @user).to be_truthy
      end

      it "allows user to view if linked company is order vendor" do
        order.vendor = Factory(:company, vendor: true)

        @user.company.linked_company_ids = [order.vendor.id]
        expect(order.can_view? @user).to be_truthy
      end
    end

    context :factory do
      before :each do
        @factory = Factory(:company, factory:true)
        order.factory = @factory
        @user = Factory(:user, company: @factory)
        allow(@user).to receive(:view_orders?).and_return true
      end

      it "allows a factory to view their orders" do
        expect(order.can_view? @user).to be_truthy
      end
    end

  end

  describe :compose_po_number do
    it "assembles a po number" do
      expect(Order.compose_po_number "A", "b").to eq "A-b"
    end
  end

  describe :shipping? do
    it "shows PO as shipping if any line has a piece set associated with a shipment" do
      order = Factory(:order_line).order
      sl = Factory(:shipment_line, product: order.order_lines.first.product)
      PieceSet.create! order_line: order.order_lines.first, shipment_line: sl, quantity: 1

      expect(order.shipping?).to be_truthy
    end

    it "does not show PO as shipping if there is no piece set associated w/ a shipment" do
      order = Factory(:order_line).order
      PieceSet.create! order_line: order.order_lines.first, quantity: 1
      expect(order.shipping?).to be_falsey
    end
  end

  describe "mark_order_as_accepted" do
    it "marks the order" do
      o = Order.new
      o.mark_order_as_accepted
      expect(o.approval_status).to eq "Accepted"
    end
  end

  require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

  describe "associate_vendor_and_products!" do
    it "should create assignments for records where they don't already exist" do
      expect_any_instance_of(ProductVendorAssignment).to receive(:create_snapshot).once
      ol = Factory(:order_line)
      ol2 = Factory(:order_line,order:ol.order)

      expect(ol.order.vendor).to_not be_nil

      associated_product = ol.product
      Factory(:product_vendor_assignment,vendor:ol.order.vendor,product:associated_product)

      expect{ol.order.associate_vendor_and_products!(Factory(:user))}.to change(ProductVendorAssignment,:count).from(1).to(2)

      pva = ProductVendorAssignment.last
      expect(pva.vendor).to eq ol.order.vendor
      expect(pva.product).to eq ol2.product
    end
  end
  describe '#available_tpp_survey_responses' do
    let :clean_survey_response do
      destination = Factory(:country,iso_code:'US')
      mc = Factory(:master_company)
      ship_to = Factory(:address,company:mc,country:destination)
      u = Factory(:vendor_user)
      vendor = u.company
      o = Factory(:order,vendor:vendor)
      Factory(:order_line,order:o,ship_to:ship_to)

      tpp = Factory(:trade_preference_program,destination_country:destination)

      survey = Factory(:survey,trade_preference_program:tpp,expiration_days:365)
      sr = survey.generate_response!(u)
      sr.submitted_date = 1.day.ago
      sr.save!
      [o,sr]
    end
    it 'should find responses' do
      o, sr = clean_survey_response
      expect(o.available_tpp_survey_responses.to_a).to eq [sr]
    end
    it 'should only include responses that are submitted' do
      o, sr = clean_survey_response
      sr.submitted_date = nil
      sr.save!
      expect(o.available_tpp_survey_responses.to_a).to eq []
    end
    it 'should only include responses where the responder is from the vendor company' do
      o = clean_survey_response.first
      o.vendor = Factory(:vendor)
      o.save!
      expect(o.available_tpp_survey_responses.to_a).to eq []
    end
    it 'should only include responses that are for a ship to country that is included in order' do
      o = clean_survey_response.first
      st = o.order_lines.first.ship_to
      st.country = Factory(:country)
      st.save!
      expect(o.available_tpp_survey_responses.to_a).to eq []
    end
    it 'should only include responses that are not expired' do
      o, sr = clean_survey_response
      sr.email_sent_date = 2.years.ago
      sr.save!
      expect(o.available_tpp_survey_responses.to_a).to eq []
    end
  end
end
