describe IntacctErrorsController do

  before :each do
    sign_in_as user
    allow(user).to receive(:in_any_group?).with(['intacct-accounting', 'canada-accounting']).and_return true
  end

  let (:user) { FactoryBot(:user) }
  let! (:master_setup) do
    ms = stub_master_setup
    allow(ms).to receive(:custom_feature?).with("WWW").and_return true
    ms
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
      u = FactoryBot(:user, username: 'notallowed')
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
      u = FactoryBot(:user, username: 'notallowed')
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

  describe "report_unfixable_check" do
    it "marks the error unfixable" do
      p1 = IntacctCheck.create! intacct_errors: "ERROR"

      put :report_unfixable_check, id: p1.id, reason: "It's broken."
      expect(response).to redirect_to action: :index
      expect(flash[:notices]).to include "Intacct Error message has been set as unfixable."
      expect(p1.reload.intacct_errors).to eql("It's broken.")
      expect(p1.reload.intacct_key).to eql("N/A")
    end

    it "rejects unapproved users" do
      u = FactoryBot(:user, username: 'notallowed')
      sign_in_as u
      p1 = IntacctCheck.create! intacct_errors: "ERROR"

      put :report_unfixable_check, id: p1.id

      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to view this Payable."
    end

    it "handles missing payable" do
      put :report_unfixable_check, id: -1

      expect(response).to redirect_to action: :index
      expect(flash[:errors]).to include "No Intacct Error message found to mark unfixable."
    end
  end

  describe "report_unfixable_receivable" do
    it "marks the error unfixable" do
      p1 = IntacctReceivable.create! intacct_errors: "ERROR"

      put :report_unfixable_receivable, id: p1.id, reason: "It's broken."
      expect(response).to redirect_to action: :index
      expect(flash[:notices]).to include "Intacct Error message has been set as unfixable."
      expect(p1.reload.intacct_errors).to eql("It's broken.")
      expect(p1.reload.intacct_key).to eql("N/A")
    end

    it "rejects unapproved users" do
      u = FactoryBot(:user, username: 'notallowed')
      sign_in_as u
      p1 = IntacctReceivable.create! intacct_errors: "ERROR"

      put :report_unfixable_receivable, id: p1.id

      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to view this Payable."
    end

    it "handles missing payable" do
      put :report_unfixable_receivable, id: -1

      expect(response).to redirect_to action: :index
      expect(flash[:errors]).to include "No Intacct Error message found to mark unfixable."
    end
  end

  describe "report_unfixable_payable" do
    it "marks the error unfixable" do
      p1 = IntacctPayable.create! intacct_errors: "ERROR"

      put :report_unfixable_payable, id: p1.id, reason: "It's broken."
      expect(response).to redirect_to action: :index
      expect(flash[:notices]).to include "Intacct Error message has been set as unfixable."
      expect(p1.reload.intacct_errors).to eql("It's broken.")
      expect(p1.reload.intacct_key).to eql("N/A")
    end

    it "rejects unapproved users" do
      u = FactoryBot(:user, username: 'notallowed')
      sign_in_as u
      p1 = IntacctPayable.create! intacct_errors: "ERROR"

      put :report_unfixable_payable, id: p1.id

      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to view this Payable."
    end

    it "handles missing payable" do
      put :report_unfixable_payable, id: -1

      expect(response).to redirect_to action: :index
      expect(flash[:errors]).to include "No Intacct Error message found to mark unfixable."
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
      u = FactoryBot(:user, username: 'notallowed')
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
      u = FactoryBot(:user, username: 'notallowed')
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
      expect(OpenChain::CustomHandler::Intacct::IntacctDataPusher).to receive(:delay).and_return OpenChain::CustomHandler::Intacct::IntacctDataPusher
      expect(OpenChain::CustomHandler::Intacct::IntacctDataPusher).to receive(:run_schedulable).with(companies: ['vfc', 'lmd', 'vcu', 'als'])

      post :push_to_intacct
      expect(response).to redirect_to action: :index
      expect(flash[:notices]).to include "All Accounting data loaded into " + MasterSetup.application_name + " without errors will be pushed to Intacct shortly."
    end

    it "rejects unapproved users" do
      u = FactoryBot(:user, username: 'notallowed')
      sign_in_as u

      post :push_to_intacct

      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to view this page."
    end
  end
end
