require 'spec_helper'

describe VfiInvoicesController do
  before(:each) do
    @u = Factory(:user)
    @inv = Factory(:vfi_invoice)
    sign_in_as @u
  end

  describe "index" do
    it "allows use only by vfi-invoice viewers" do
      get :index

      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include "You do not have permission to view VFI invoices."
    end

    it "renders" do
      allow(@u).to receive(:view_vfi_invoices?).and_return true
      get :index
      expect(response).to be_redirect
      expect(response.location).to match(/\/advanced_search#\//)
    end
  end

  describe "show" do
    it "allows use only by vfi-statement viewers" do
      get :show, id: @inv

      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include "You do not have permission to view VFI invoices."
    end

    it "allows use only by user with permission to view invoice" do
      allow(@u).to receive(:view_vfi_invoices?).and_return true
      allow_any_instance_of(VfiInvoice).to receive(:can_view?).with(@u).and_return false

      get :show, id: @inv
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include "You do not have permission to view this invoice."     
    end

    it "renders and totals invoices" do
      Factory(:vfi_invoice_line, vfi_invoice: @inv, charge_amount: 5)
      Factory(:vfi_invoice_line, vfi_invoice: @inv, charge_amount: 3)

      @u.company = Factory(:master_company)
      allow(@u).to receive(:view_vfi_invoices?).and_return true
      
      get :show, id: @inv
      expect(response).to be_success
      expect(assigns(:vfi_invoice)).to eq @inv
    end
  end

end