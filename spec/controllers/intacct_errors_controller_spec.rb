require 'spec_helper'

describe IntacctErrorsController do
  before :each do
    MasterSetup.any_instance.stub(:system_code).and_return "www-vfitrack-net"
    g = Group.create! system_code: 'intacct-accounting'
    @user = Factory(:user, username: "jhulford")
    @user.groups << g
    sign_in_as @user
  end

  describe "index" do
    it "finds all errored intacct objects" do
      r1 = IntacctReceivable.create! intacct_errors: "ERROR"
      r2 = IntacctReceivable.create! intacct_errors: "ERROR", intacct_key: "KEY"
      p1 = IntacctPayable.create! intacct_errors: "ERROR"
      p2 = IntacctPayable.create! intacct_errors: "ERROR", intacct_key: "KEY"
      c1 = IntacctCheck.create! intacct_errors: "ERROR"
      c2 = IntacctCheck.create! intacct_errors: "ERROR", intacct_key: "KEY"

      get :index

      expect(response).to be_success
      expect(assigns(:receivables)).to eq [r1]
      expect(assigns(:payables)).to eq [p1]
      expect(assigns(:checks)).to eq [c1]
    end

    it "rejects unapproved users" do
      u = Factory(:user, username: 'notallowed')
      sign_in_as u

      get :index
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to view this page."
    end
  end

  describe "clear_receivable" do
    it "clears an error from receivable" do
      p1 = IntacctReceivable.create! intacct_errors: "ERROR"

      put :clear_receivable, id: p1.id

      expect(response).to redirect_to action: :index
      expect(flash[:notices]).to include "Intacct Error message has been cleared.  The Receivable will be re-sent when the next integration process runs."
      expect(p1.reload.intacct_errors).to be_nil
    end

    it "rejects unapproved users" do
      u = Factory(:user, username: 'notallowed')
      sign_in_as u
      p1 = IntacctReceivable.create! intacct_errors: "ERROR"

      put :clear_receivable, id: p1.id
      
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to view this Receivable."
    end

    it "handles missing receivable" do
      put :clear_receivable, id: -1

      expect(response).to redirect_to action: :index
      expect(flash[:errors]).to include "No Intacct Error message found to clear."
    end
  end

  describe "clear_payable" do
    it "clears an error from payable" do
      p1 = IntacctPayable.create! intacct_errors: "ERROR"

      put :clear_payable, id: p1.id

      expect(response).to redirect_to action: :index
      expect(flash[:notices]).to include "Intacct Error message has been cleared.  The Payable will be re-sent when the next integration process runs."
      expect(p1.reload.intacct_errors).to be_nil
    end

    it "rejects unapproved users" do
      u = Factory(:user, username: 'notallowed')
      sign_in_as u
      p1 = IntacctPayable.create! intacct_errors: "ERROR"

      put :clear_payable, id: p1.id
      
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to view this Payable."
    end

    it "handles missing payable" do
      put :clear_payable, id: -1

      expect(response).to redirect_to action: :index
      expect(flash[:errors]).to include "No Intacct Error message found to clear."
    end
  end

  describe "clear_check" do
    it "clears an error from check" do
      c1 = IntacctCheck.create! intacct_errors: "ERROR"

      put :clear_check, id: c1.id

      expect(response).to redirect_to action: :index
      expect(flash[:notices]).to include "Intacct Error message has been cleared.  The Check will be re-sent when the next integration process runs."
      expect(c1.reload.intacct_errors).to be_nil
    end

    it "rejects unapproved users" do
      u = Factory(:user, username: 'notallowed')
      sign_in_as u
      c1 = IntacctCheck.create! intacct_errors: "ERROR"

      put :clear_check, id: c1.id
      
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to view this Check."
    end

    it "handles missing payable" do
      put :clear_check, id: -1

      expect(response).to redirect_to action: :index
      expect(flash[:errors]).to include "No Intacct Error message found to clear."
    end
  end

  describe "push_to_intacct" do
    it "calls intacct data pusher in delayed manner" do
      OpenChain::CustomHandler::Intacct::IntacctDataPusher.should_receive(:delay).and_return OpenChain::CustomHandler::Intacct::IntacctDataPusher
      OpenChain::CustomHandler::Intacct::IntacctDataPusher.should_receive(:run_schedulable).with(companies: ['vfc', 'lmd', 'vcu', 'als'])

      post :push_to_intacct
      expect(response).to redirect_to action: :index
      expect(flash[:notices]).to include "All Accounting data loaded into VFI Track without errors will be pushed to Intacct shortly."      
    end

    it "rejects unapproved users" do
      u = Factory(:user, username: 'notallowed')
      sign_in_as u

      post :push_to_intacct
      
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to view this page."
    end
  end
end