require 'spec_helper'

describe SummaryStatementsController do
  before(:each) do
    @u = Factory(:user)
    @ss = Factory(:summary_statement)
    sign_in_as @u
  end

  describe :index do
    it "allows use only by summary-statement viewers" do
      get :index

      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include "You do not have permission to view summary statements."
    end

    it "renders" do
      @u.stub(:view_summary_statements?).and_return true
      get :index
      response.should be_redirect
      expect(response.location).to match(/\/advanced_search#\//)
    end
  end

  describe :show do
    it "allows use only by summary-statement viewers" do
      get :show, id: @ss

      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include "You do not have permission to view summary statements."
    end

    it "renders" do
      @u.stub(:view_summary_statements?).and_return true
      us_entry = Factory(:entry, import_country: Factory(:country, iso_code: 'US'))
      ca_entry = Factory(:entry, import_country: Factory(:country, iso_code: 'CA'))
      bi_1 = Factory(:broker_invoice, entry: us_entry)
      bi_2 = Factory(:broker_invoice, entry: ca_entry)
      bi_3 = Factory(:broker_invoice, entry: ca_entry)
      @ss.broker_invoices << [bi_1, bi_2, bi_3]
      
      get :show, id: @ss
      expect(response).to be_success
      expect(assigns(:summary_statement)).to eq @ss  
      expect(assigns(:us_invoices)).to eq [bi_1]
      expect(assigns(:ca_invoices)).to eq [bi_2, bi_3]
    end
  end

  describe :edit do
    it "allows use only by summary-statement editors" do
      get :edit, id: @ss

      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include "You do not have permission to edit summary statements."
    end

    it "renders" do
      @u.stub(:edit_summary_statements?).and_return true
      us_entry = Factory(:entry, import_country: Factory(:country, iso_code: 'US'))
      ca_entry = Factory(:entry, import_country: Factory(:country, iso_code: 'CA'))
      bi_1 = Factory(:broker_invoice, entry: us_entry)
      bi_2 = Factory(:broker_invoice, entry: ca_entry)
      bi_3 = Factory(:broker_invoice, entry: ca_entry)
      @ss.broker_invoices << [bi_1, bi_2, bi_3]
      
      get :edit, id: @ss
      expect(response).to be_success
      expect(assigns(:summary_statement)).to eq @ss
      expect(assigns(:us_invoices)).to eq [bi_1]
      expect(assigns(:ca_invoices)).to eq [bi_2, bi_3]
    end
  end

  describe :new do
    it "allows use only by summary-statement editors" do
      get :new
      
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include "You do not have permission to create summary statements."
    end

    it "filters the choice of companies" do
      c1 = Factory(:company, importer: true)
      c2 = Factory(:company, importer: true)
      Factory(:company)

      get :new
      expect(assigns(:companies).sort).to eq [c1, c2].sort
    end

    it "renders" do
      @u.stub(:edit_summary_statements?).and_return true
      get :new

      expect(response).to be_success
    end
  end

  describe :create do
    before(:each) do
      @u.stub(:edit_summary_statements?).and_return true
      @co_1 = Factory(:company, importer: true)
      @co_2 = Factory(:company)
      
    end

    it "allows use only by summary-statement editors" do
      @u.stub(:edit_summary_statements?).and_return false
      post :create, company: @co_1.id.to_s, stat_num: "12356789"
      expect(SummaryStatement.count).to eq 1
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include "You do not have permission to create summary statements."
    end

    it "prevents selection of non-importers" do
      post :create, company: @co_2.id.to_s, stat_num: "12356789"
      expect(SummaryStatement.count).to eq 1
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include "This company cannot be assigned summary statements."
    end

    it "validates presence of summary-statement number" do
      post :create, company: @co_1.id.to_s
      expect(SummaryStatement.count).to eq 1
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include "Statement number can't be blank"
    end

    it "create a new summary statement and redirect to #edit" do
      post :create, company: @co_1.id.to_s, stat_num: "123456789"
      expect(SummaryStatement.count).to eq 2
      expect(response).to redirect_to edit_summary_statement_path(SummaryStatement.last)
    end

  end

  describe :update do
    before(:each) do
      @u.stub(:edit_summary_statements?).and_return true
    end

    it "allows use only by summary-statement editors" do
      @u.stub(:edit_summary_statements?).and_return false
      put :update, id: @ss, selected: {to_remove: [@bi_1, @bi_2]}

      expect(response).to redirect_to request.referrer
    end

    it "redirects if no selections are made" do
      put :update, id: @ss
      expect(response).to redirect_to request.referrer
    end

    context "removing invoices" do
      before(:each) do
        @bi_1 = Factory(:broker_invoice, summary_statement: @ss).id.to_s
        @bi_2 = Factory(:broker_invoice, summary_statement: @ss).id.to_s
        Factory(:broker_invoice, summary_statement: @ss).id.to_s
      end

      it "removes invoices from statement" do
        put :update, id: @ss, selected: {to_remove: [@bi_1, @bi_2]}
        
        expect(@ss.broker_invoices.count).to eq 1
        expect(response).to redirect_to edit_summary_statement_path(@ss)
      end

      it "makes no change and displays error if an invoice marked for removal doesn't belong to the statement" do
        bi_other = Factory(:broker_invoice, invoice_number: "123456789").id.to_s
        
        put :update, id: @ss, selected: {to_remove: [@bi_1, bi_other]}
        expect(@ss.broker_invoices.count).to eq 3
        expect(response).to redirect_to request.referrer
        expect(flash[:errors]).to include "Invoice 123456789 is not on this statement."
      end
    end

    context "adding invoices" do
      before(:each) do
        @company = Factory(:company)
        @ss.customer = @company
        @ss.save!
      end

      it "adds invoices to statement" do
        Factory(:broker_invoice, invoice_number: '123456789', entry: Factory(:entry, importer: @company))
        Factory(:broker_invoice, invoice_number: '987654321', entry: Factory(:entry, importer: @company))
        put :update, id: @ss, selected: {to_add: "123456789\n987654321"}
        
        expect(@ss.broker_invoices.count).to eq 2
        expect(response).to redirect_to edit_summary_statement_path(@ss)
      end

      it "makes no change and displays error if an invoice is ineligible to be added" do
        Factory(:broker_invoice, invoice_number: '123456789', entry: Factory(:entry, importer: Factory(:company))).id.to_s
        put :update, id: @ss, selected: {to_add: "123456789"}
        
        expect(@ss.broker_invoices.count).to eq 0
        expect(response).to redirect_to request.referrer
        expect(flash[:errors]).to include "Invoice 123456789 does not belong to customer."
      end

      it "makes no change and displays error if invoice number doesn't exist" do
        put :update, id: @ss, selected: {to_add: "123456789"}
        expect(@ss.broker_invoices.count).to eq 0
        expect(response).to redirect_to request.referrer
        expect(flash[:errors]).to include "Invoice 123456789 does not exist."
      end
    end
  end

end



