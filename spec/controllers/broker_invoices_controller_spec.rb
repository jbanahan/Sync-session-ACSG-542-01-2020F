require 'spec_helper'

describe BrokerInvoicesController do
  before :each do 
    MasterSetup.get.update_attributes(:entry_enabled=>true,:broker_invoice_enabled=>true)

    @user = Factory(:user,:company=>Factory(:company,:master=>true),:broker_invoice_edit=>true,:entry_view=>true)
    sign_in_as @user
  end
  describe :create do
    before :each do 
      @entry = Factory(:entry)
    end
    context "security" do
      it "should not let users without ability to view host entry" do
        Entry.any_instance.stub(:can_view?).and_return(false)
        post :create, {'entry_id'=>@entry.id, 'broker_invoice'=>{'suffix'=>'a'}}
        response.should be_redirect
        flash[:errors].should have(1).message
      end
      it "should not let users without the ability to edit invoices" do
        @user.update_attributes(:broker_invoice_edit=>false)
        post :create, {'entry_id'=>@entry.id, 'broker_invoice'=>{'suffix'=>'a'}}
        response.should be_redirect
        flash[:errors].should have(1).message
      end
      it "should not process without an entry_id" do
        lambda {post :create, {'broker_invoice'=>{'suffix'=>'a'}}}.should raise_error
      end
    end
    it "should not create invoices without lines" do
      post :create, {'entry_id'=>@entry.id, 'broker_invoice'=>{'suffix'=>'a'}}
      response.should redirect_to @entry
      flash[:errors].first.should == "Cannot create invoice without lines."
      BrokerInvoice.first.should be_nil
    end
    it "should create invoice with invoice lines" do
      post :create, {'entry_id'=>@entry.id, 'broker_invoice'=>{'suffix'=>'a','broker_invoice_lines_attributes'=>{'1'=>{'charge_description'=>'x','charge_amount'=>'12.21'}}}}
      response.should redirect_to @entry
      flash[:errors].should be_empty unless flash[:errors].nil?
      bi = BrokerInvoice.first
      bi.entry.should == @entry
      bi.suffix.should == 'a'
      bi.broker_invoice_lines.should have(1).line
      bi.broker_invoice_lines.first.charge_description.should == 'x'
      bi.broker_invoice_lines.first.charge_amount.should == 12.21
    end
    it "should update invoice total" do
      post :create, {'entry_id'=>@entry.id, 'broker_invoice'=>
        {'suffix'=>'a','broker_invoice_lines_attributes'=>{
          '1'=>{'charge_description'=>'x','charge_amount'=>'12.21'},'2'=>{'charge_description'=>'y','charge_amount'=>'14.00'}}}}
      response.should redirect_to @entry
      flash[:errors].should be_empty unless flash[:errors].nil?
      BrokerInvoice.first.invoice_total.should == 26.21
    end
  end
end
