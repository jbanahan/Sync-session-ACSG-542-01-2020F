require 'spec_helper'

describe BrokerInvoicesController do
  before :each do 
    MasterSetup.get.update_attributes(:entry_enabled=>true,:broker_invoice_enabled=>true)

    @user = Factory(:user,:company=>Factory(:company,:master=>true),:broker_invoice_edit=>true,:entry_view=>true)
    sign_in_as @user
  end
  describe "create" do
    before :each do 
      @entry = Factory(:entry)
    end
    context "security" do
      it "should not let users without ability to view host entry" do
        allow_any_instance_of(Entry).to receive(:can_view?).and_return(false)
        post :create, {'entry_id'=>@entry.id, 'broker_invoice'=>{'suffix'=>'a'}}
        expect(response).to be_redirect
        expect(flash[:errors].size).to eq(1)
      end
      it "should not let users without the ability to edit invoices" do
        @user.update_attributes(:broker_invoice_edit=>false)
        post :create, {'entry_id'=>@entry.id, 'broker_invoice'=>{'suffix'=>'a'}}
        expect(response).to be_redirect
        expect(flash[:errors].size).to eq(1)
      end
      it "should not process without an entry_id" do
        expect {post :create, {'broker_invoice'=>{'suffix'=>'a'}}}.to raise_error
      end
    end
    it "should not create invoices without lines" do
      post :create, {'entry_id'=>@entry.id, 'broker_invoice'=>{'suffix'=>'a'}}
      expect(response).to redirect_to @entry
      expect(flash[:errors].first).to eq("Cannot create invoice without lines.")
      expect(BrokerInvoice.first).to be_nil
    end
    it "should create invoice with invoice lines" do
      post :create, {'entry_id'=>@entry.id, 'broker_invoice'=>{'suffix'=>'a','broker_invoice_lines_attributes'=>{'1'=>{'charge_description'=>'x','charge_amount'=>'12.21'}}}}
      expect(response).to redirect_to @entry
      expect(flash[:errors]).to be_empty unless flash[:errors].nil?
      bi = BrokerInvoice.first
      expect(bi.entry).to eq(@entry)
      expect(bi.suffix).to eq('a')
      expect(bi.broker_invoice_lines.size).to eq(1)
      expect(bi.broker_invoice_lines.first.charge_description).to eq('x')
      expect(bi.broker_invoice_lines.first.charge_amount).to eq(12.21)
    end
    it "should update invoice total" do
      post :create, {'entry_id'=>@entry.id, 'broker_invoice'=>
        {'suffix'=>'a','broker_invoice_lines_attributes'=>{
          '1'=>{'charge_description'=>'x','charge_amount'=>'12.21'},'2'=>{'charge_description'=>'y','charge_amount'=>'14.00'}}}}
      expect(response).to redirect_to @entry
      expect(flash[:errors]).to be_empty unless flash[:errors].nil?
      expect(BrokerInvoice.first.invoice_total).to eq(26.21)
    end
  end
end
