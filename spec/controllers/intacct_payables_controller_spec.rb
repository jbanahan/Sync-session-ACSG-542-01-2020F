require 'spec_helper'

describe IntacctPayablesController do
  before :each do
    MasterSetup.any_instance.stub(:system_code).and_return "www-vfitrack-net"
    @user = Factory(:user, username: "jhulford")
    sign_in_as @user
  end

  describe "index" do
    it "finds all errored payables" do
      p1 = IntacctPayable.create! intacct_errors: "ERROR"
      p2 = IntacctPayable.create! intacct_errors: "ERROR", intacct_key: "KEY"

      get :index

      expect(response).to be_success
      errors = assigns(:errors)
      expect(errors.size).to eq 1
      expect(errors.first).to eq p1
    end

    it "rejects unapproved users" do
      u = Factory(:user, username: 'notallowed')
      sign_in_as u

      get :index
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to view this Payable."
    end
  end

  describe "clear" do
    it "clears an error from payable" do
      p1 = IntacctPayable.create! intacct_errors: "ERROR"

      put :clear, id: p1.id

      expect(response).to redirect_to action: :index
      expect(flash[:notices]).to include "Intacct Error message has been cleared.  The Payable will be re-sent when the next integration process runs."
      expect(p1.reload.intacct_errors).to be_nil
    end

    it "rejects unapproved users" do
      u = Factory(:user, username: 'notallowed')
      sign_in_as u
      p1 = IntacctPayable.create! intacct_errors: "ERROR"

      put :clear, id: p1.id
      
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to view this Payable."
    end

    it "handles missing payable" do
      put :clear, id: -1

      expect(response).to redirect_to action: :index
      expect(flash[:errors]).to include "No Intacct Error message found to clear."
    end
  end
end