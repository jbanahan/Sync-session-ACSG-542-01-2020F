require 'spec_helper'

describe Order do

  before :each do
    LinkedAttachment.destroy_all
  end
  describe 'linkable attachments' do
    it 'should have linkable attachments' do
      o = Factory(:order,:order_number=>'ordn')
      linkable = Factory(:linkable_attachment,:model_field_uid=>'ord_ord_num',:value=>'ordn')
      linked = LinkedAttachment.create(:linkable_attachment_id=>linkable.id,:attachable=>o)
      o.reload
      o.linkable_attachments.first.should == linkable
    end
  end

  describe 'all attachments' do
    before :each do
      @o = Factory(:order)
    end
    it 'should return all_attachments when only regular attachments' do
      a = @o.attachments.create!
      all = @o.all_attachments
      all.should have(1).attachment
      all.first.should == a
    end
    it 'should return all_attachments when only linked attachents' do
      linkable = Factory(:linkable_attachment,:model_field_uid=>'ord_ord_num',:value=>@o.order_number)
      a = linkable.build_attachment
      a.save!
      @o.linked_attachments.create!(:linkable_attachment_id=>linkable.id)
      all = @o.all_attachments
      all.should have(1).attachment
      all.first.should == a
    end
    it 'should return all_attachments when both attachments' do
      a = @o.attachments.create!
      linkable = Factory(:linkable_attachment,:model_field_uid=>'ord_ord_num',:value=>@o.order_number)
      linkable_a = linkable.build_attachment
      linkable_a.save!
      @o.linked_attachments.create!(:linkable_attachment_id=>linkable.id)
      all = @o.all_attachments
      all.should have(2).attachments
      all.should include(a)
      all.should include(linkable_a)
    end
    it 'should return empty array when no attachments' do
      @o.all_attachments.should be_empty
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
        @user.stub(:view_orders?).and_return true
      end

      it "allows an importer to view their orders" do
        expect(order.can_view? @user).to be_true
      end

      it "allows user to view if linked company is order importer" do
        order.importer = Factory(:company, importer: true)

        @user.company.linked_company_ids = [order.importer.id]
        expect(order.can_view? @user).to be_true
      end
    end

    context :vendor do 
      before :each do 
        @vendor = Factory(:company, vendor: true)
        order.vendor = @vendor
        @user = Factory(:user, company: @vendor)
        @user.stub(:view_orders?).and_return true
      end

      it "allows a vendor to view their orders" do
        expect(order.can_view? @user).to be_true
      end

      it "allows user to view if linked company is order vendor" do
        order.vendor = Factory(:company, vendor: true)

        @user.company.linked_company_ids = [order.vendor.id]
        expect(order.can_view? @user).to be_true
      end
    end
    
  end

end
