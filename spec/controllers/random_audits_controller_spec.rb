require 'spec_helper'

describe RandomAuditsController do
  let(:u) { Factory(:user) }
  let!(:ra) { Factory(:random_audit, user: u) }
  before { sign_in_as u }

  describe "download" do
    it "allows admin to download integration file" do
      expect_any_instance_of(RandomAudit).to receive(:secure_url).and_return "http://redirect.com"
      expect_any_instance_of(RandomAudit).to receive(:can_view?).with(u).and_return true

      get :download, id: ra.id
      expect(response).to redirect_to("http://redirect.com")
    end

    it "disallows users that can't view object" do
      allow_any_instance_of(RandomAudit).to receive(:can_view?).with(u).and_return false
      get :download, id: ra.id
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to download this random audit."
    end
  end
end
