require 'spec_helper'

describe ShipmentsController do
  before :each do

  end
  context 'invoice generation' do
    before :each do
      @shipment = Factory(:shipment)
      @prod_1 = Factory(:product,:vendor=>@shipment.vendor)
      @shipment_line_1 = Factory(:shipment_line,:product=>@prod_1,:shipment=>@shipment,:quantity=>10)
      @order_1 = Factory(:order,:vendor=>@shipment.vendor)
      @order_line_1 = Factory(:order_line,:product=>@prod_1,:order=>@order_1,:quantity=>20)
      @piece_set = PieceSet.create!(:order_line_id=>@order_line_1.id,:shipment_line_id=>@shipment_line_1.id,:quantity=>10)
      @shipment_line_2 = Factory(:shipment_line,:product=>@prod_1,:shipment=>@shipment,:quantity=>8)
      @order_2 = Factory(:order,:vendor=>@shipment.vendor)
      @order_line_2 = Factory(:order_line,:product=>@prod_1,:order=>@order_2,:quantity=>100)
      @existing_ci_line = Factory(:commercial_invoice_line)
      @piece_set = PieceSet.create!(:order_line_id=>@order_line_2.id,:shipment_line_id=>@shipment_line_2.id,
        :commercial_invoice_line_id=>@existing_ci_line.id,:quantity=>8)
      @u = Factory(:user,:shipment_edit=>true,:company=>Factory(:company,:master=>true))
      sign_in_as @u
    end
    describe 'make_invoice' do
      it "should not display if user cannot edit shipment" do
        Shipment.any_instance.stub(:can_edit?).and_return(false)
        get :make_invoice, :id=>@shipment.id
        response.should redirect_to request.referrer
      end
      it "should separate lines based on if they are already on an invoice" do
        Shipment.any_instance.stub(:can_edit?).and_return(true)
        get :make_invoice, :id=>@shipment.id
        response.should be_success
        assigns(:available_lines).should == [@shipment_line_1]
        assigns(:used_lines).should == [@shipment_line_2]
      end
    end
    describe 'generate_invoice' do
      it "should not run if user cannot edit shipment" do
        Shipment.any_instance.stub(:can_edit?).and_return(false)
        put :generate_invoice, :id=>@shipment.id
        response.should redirect_to request.referrer
      end
      it "should only process lines that aren't already on an invoice" do
        Shipment.any_instance.stub(:can_edit?).and_return(true)
        CommercialInvoiceMap.should_receive(:generate_invoice!).with(@u, [@shipment_line_1], {})
        #should not process shipment line 2 because it is on a shipment already.  Screen won't allow it, but we should have the same check in the controller
        put :generate_invoice, :id=>@shipment.id, :shpln=>{"1"=>@shipment_line_1.id.to_s,"2"=>@shipment_line_2.id.to_s}
        response.should redirect_to @shipment
        flash[:notices].should == ["Commercial Invoice created successfully."]
      end
    end
  end
end
